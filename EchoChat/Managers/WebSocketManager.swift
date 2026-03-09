//
//  WebSocketManager.swift
//  EchoChat
//
//  Manages the WebSocket connection to the Node.js backend at ws://localhost:8080.
//  Uses URLSessionWebSocketTask (native, no third-party dependency).
//

import Foundation
import Combine

final class WebSocketManager: ObservableObject {
    // MARK: - Published State

    /// All messages in the current session (sent + received).
    @Published var messages: [ChatMessage] = []
    /// Whether the socket is currently connected.
    @Published var isConnected: Bool = false

    // MARK: - Private

    private var task: URLSessionWebSocketTask?
    private let url = URL(string: "ws://localhost:8080")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Connect

    /// Opens the WebSocket connection and begins listening for messages.
    func connect() {
        // TODO: Replace hard-coded URL with a configurable environment constant.
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        receiveMessages()
    }

    // MARK: - Disconnect

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    // MARK: - Receive (recursive)

    /// Continuously listens for incoming frames using a recursive receive loop.
    private func receiveMessages() {
        task?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let jsonString):
                    self.handleIncoming(jsonString: jsonString)
                case .data(let data):
                    // Fallback: treat raw data as UTF-8 JSON.
                    if let jsonString = String(data: data, encoding: .utf8) {
                        self.handleIncoming(jsonString: jsonString)
                    }
                @unknown default:
                    break
                }
                // Keep the loop alive for the next message.
                self.receiveMessages()

            case .failure(let error):
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                print("[WebSocketManager] Receive error: \(error.localizedDescription)")
                // TODO: Implement reconnection back-off strategy.
            }
        }
    }

    // MARK: - Handle Incoming JSON

    private func handleIncoming(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }

        // Step 1: Decode the outer envelope to inspect the raw text field.
        guard let rawMessage = try? decoder.decode(ChatMessage.self, from: data) else {
            print("[WebSocketManager] Decode error — dropping frame")
            return
        }

        // Step 2: Check for call-signalling token BEFORE attempting decryption.
        // The signal token is sent in plain text so all clients can detect it.
        if rawMessage.text == kCallRingingSignal {
            let callerName = rawMessage.senderName
            let callUUID   = UUID()
            print("[WebSocketManager] CALL_RINGING received from '\(callerName)' — reporting to CallKit")
            DispatchQueue.main.async {
                CallManager.shared.reportIncomingCall(uuid: callUUID, callerName: callerName)
            }
            return  // Do NOT add this to the chat message list.
        }

        // Step 3: Normal message — decrypt and append.
        if let decryptedText = CryptoManager.shared.decrypt(base64String: rawMessage.text) {
            let chatMessage = ChatMessage(
                id: rawMessage.id,
                senderId: rawMessage.senderId,
                senderName: rawMessage.senderName,
                text: decryptedText,
                timestamp: rawMessage.timestamp
            )
            DispatchQueue.main.async {
                self.messages.append(chatMessage)
            }
        } else {
            print("[WebSocketManager] Decryption failed — dropping message")
        }
    }

    // MARK: - Send

    /// Sends a message over WebSocket.
    /// - Regular messages are AES-GCM encrypted before sending.
    /// - Signalling tokens (e.g. "[[CALL_RINGING]]") are sent in plain text
    ///   and are NOT appended to the local chat list.
    func sendMessage(text: String, senderId: String, senderName: String) {
        let isSignal = text == kCallRingingSignal

        // Determine the wire payload text.
        let wireText: String
        if isSignal {
            // Send signalling tokens unencrypted so every peer can detect them.
            wireText = text
        } else {
            // Encrypt regular chat text.
            guard let encrypted = CryptoManager.shared.encrypt(message: text) else {
                print("[WebSocketManager] Encryption failed — message not sent")
                return
            }
            wireText = encrypted
        }

        let wireMessage = ChatMessage(senderId: senderId, senderName: senderName, text: wireText)

        do {
            let data = try encoder.encode(wireMessage)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            task?.send(.string(jsonString)) { error in
                if let error {
                    print("[WebSocketManager] Send error: \(error.localizedDescription)")
                    // TODO: Queue the message for retry on failure.
                }
            }
        } catch {
            print("[WebSocketManager] Encode error: \(error.localizedDescription)")
            return
        }

        // Append to the local chat list only for regular messages.
        // Signalling tokens must not appear in the conversation history.
        guard !isSignal else { return }

        let localMessage = ChatMessage(senderId: senderId, senderName: senderName, text: text)
        DispatchQueue.main.async {
            self.messages.append(localMessage)
        }
    }
}
