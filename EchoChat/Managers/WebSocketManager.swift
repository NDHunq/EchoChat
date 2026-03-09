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
        do {
            var chatMessage = try decoder.decode(ChatMessage.self, from: data)

            // Decrypt the cipher-text received from the server back to plain text.
            if let decryptedText = CryptoManager.shared.decrypt(base64String: chatMessage.text) {
                chatMessage = ChatMessage(
                    id: chatMessage.id,
                    senderId: chatMessage.senderId,
                    senderName: chatMessage.senderName,
                    text: decryptedText,
                    timestamp: chatMessage.timestamp
                )
            } else {
                print("[WebSocketManager] Decryption failed — dropping message")
                return
            }

            DispatchQueue.main.async {
                self.messages.append(chatMessage)
            }
        } catch {
            print("[WebSocketManager] Decode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Send

    /// Encrypts the message text, encodes it as JSON, and sends it over the socket.
    /// Because the backend does NOT echo back to the sender, we also
    /// append the message in plain text locally so it appears in the sender's UI immediately.
    func sendMessage(text: String, senderId: String, senderName: String) {

        // 1. Encrypt the plain text — only the cipher-text travels over the network.
        guard let encryptedText = CryptoManager.shared.encrypt(message: text) else {
            print("[WebSocketManager] Encryption failed — message not sent")
            return
        }

        // 2. Build the wire payload with the encrypted text.
        let wireMessage = ChatMessage(
            senderId: senderId,
            senderName: senderName,
            text: encryptedText         // ← cipher-text goes to the server
        )

        // TODO: Add message delivery status tracking (sent / delivered / read).

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
        }

        // 3. Append locally in plain text — backend does not echo to the sender.
        let localMessage = ChatMessage(
            senderId: senderId,
            senderName: senderName,
            text: text                  // ← plain text shown in sender's UI
        )
        DispatchQueue.main.async {
            self.messages.append(localMessage)
        }
    }
}
