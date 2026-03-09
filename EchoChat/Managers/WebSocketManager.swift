//
//  WebSocketManager.swift
//  EchoChat
//

import Foundation
import Combine

// MARK: - Call State

enum CallState: Equatable {
    case idle
    case calling        // outgoing, waiting for answer
    case ringing        // incoming, waiting for us to accept
    case inCall         // connected
}

// MARK: - Signalling Constants

let kCallInviteSignal  = "[[CALL_INVITE]]"
let kCallAcceptSignal  = "[[CALL_ACCEPT]]"
let kCallEndSignal     = "[[CALL_END]]"

/// Legacy alias kept for CallManager compatibility.
let kCallRingingSignal = kCallInviteSignal

private let kAllSignals: Set<String> = [kCallInviteSignal, kCallAcceptSignal, kCallEndSignal]

// MARK: - WebSocketManager

final class WebSocketManager: ObservableObject {

    // MARK: Published State
    @Published var messages: [ChatMessage] = []
    @Published var isConnected: Bool = false
    @Published var currentCallState: CallState = .idle
    @Published var activeCallPartnerName: String = ""

    // MARK: Private
    private var task: URLSessionWebSocketTask?
    private let url = URL(string: "ws://localhost:8080")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Connect

    func connect() {
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

    private func receiveMessages() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let json):       self.handleIncoming(jsonString: json)
                case .data(let data):
                    if let json = String(data: data, encoding: .utf8) { self.handleIncoming(jsonString: json) }
                @unknown default: break
                }
                self.receiveMessages()
            case .failure(let error):
                DispatchQueue.main.async { self.isConnected = false }
                print("[WebSocketManager] Receive error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Handle Incoming

    private func handleIncoming(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let raw = try? decoder.decode(ChatMessage.self, from: data) else {
            print("[WebSocketManager] Decode error — dropping frame")
            return
        }

        // ── Signalling intercept (plain text, before decryption) ──────────────
        switch raw.text {

        case kCallInviteSignal:
            print("[WebSocketManager] CALL_INVITE from '\(raw.senderName)'")
            DispatchQueue.main.async {
                self.activeCallPartnerName = raw.senderName
                self.currentCallState = .ringing
                CallManager.shared.reportIncomingCall(uuid: UUID(), callerName: raw.senderName)
            }
            return

        case kCallAcceptSignal:
            print("[WebSocketManager] CALL_ACCEPT from '\(raw.senderName)' — call is now connected")
            DispatchQueue.main.async {
                self.currentCallState = .inCall
            }
            return

        case kCallEndSignal:
            print("[WebSocketManager] CALL_END from '\(raw.senderName)' — call terminated")
            DispatchQueue.main.async {
                self.currentCallState = .idle
                self.activeCallPartnerName = ""
                CallManager.shared.endActiveCall()
            }
            return

        default:
            break   // fall through to normal message handling
        }

        // ── Regular encrypted message ─────────────────────────────────────────
        guard let decryptedText = CryptoManager.shared.decrypt(base64String: raw.text) else {
            print("[WebSocketManager] Decryption failed — dropping message")
            return
        }
        let chatMessage = ChatMessage(
            id: raw.id, senderId: raw.senderId,
            senderName: raw.senderName, text: decryptedText, timestamp: raw.timestamp
        )
        DispatchQueue.main.async { self.messages.append(chatMessage) }
    }

    // MARK: - Send

    func sendMessage(text: String, senderId: String, senderName: String) {
        let isSignal = kAllSignals.contains(text)

        let wireText: String
        if isSignal {
            wireText = text     // signals travel unencrypted
        } else {
            guard let encrypted = CryptoManager.shared.encrypt(message: text) else {
                print("[WebSocketManager] Encryption failed — message not sent")
                return
            }
            wireText = encrypted
        }

        let wireMessage = ChatMessage(senderId: senderId, senderName: senderName, text: wireText)
        guard let data = try? encoder.encode(wireMessage),
              let json = String(data: data, encoding: .utf8) else { return }

        task?.send(.string(json)) { error in
            if let error { print("[WebSocketManager] Send error: \(error.localizedDescription)") }
        }

        // Only append regular messages to the chat history.
        // Signalling tokens must not appear in the conversation history.
        guard !isSignal else { return }
        let local = ChatMessage(senderId: senderId, senderName: senderName, text: text)
        DispatchQueue.main.async { self.messages.append(local) }
    }
}
