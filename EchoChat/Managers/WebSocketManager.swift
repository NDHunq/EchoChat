//
//  WebSocketManager.swift
//  EchoChat
//

import Foundation
import Combine

// MARK: - Call State

enum CallState: Equatable {
    case idle
    case calling
    case ringing
    case inCall
}

// MARK: - Signalling Constants

let kCallInviteSignal   = "[[CALL_INVITE]]"
let kCallAcceptSignal   = "[[CALL_ACCEPT]]"
let kCallEndSignal      = "[[CALL_END]]"
let kCallDeclineSignal  = "[[CALL_DECLINE]]"
let kCallLogPrefix      = "[[CALL_LOG]]"   // [[CALL_LOG]]:Missed | :Declined | :Ended:05:20

let kCallRingingSignal  = kCallInviteSignal   // legacy alias

private let kAllSignals: Set<String> = [
    kCallInviteSignal, kCallAcceptSignal, kCallEndSignal, kCallDeclineSignal
]

// MARK: - WebSocketManager

final class WebSocketManager: ObservableObject {

    // MARK: Published State
    @Published var messages: [ChatMessage] = []
    @Published var isConnected: Bool = false
    @Published var currentCallState: CallState = .idle {
        didSet { if currentCallState == .inCall { callStartTime = Date() } }
    }
    @Published var activeCallPartnerName: String = ""

    // MARK: Call Tracking
    var callStartTime: Date? = nil
    /// Only the device that sent CALL_INVITE generates the [[CALL_LOG]] card.
    var isCaller: Bool = false

    // MARK: Private
    private var task: URLSessionWebSocketTask?
    private let url = URL(string: "ws://localhost:8080")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Connect / Disconnect

    func connect() {
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        receiveMessages()
    }

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
                case .string(let json):  self.handleIncoming(jsonString: json)
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

        switch raw.text {

        case kCallInviteSignal:
            print("[WebSocketManager] CALL_INVITE from '\(raw.senderName)'")
            DispatchQueue.main.async {
                self.isCaller = false
                self.activeCallPartnerName = raw.senderName
                self.currentCallState = .ringing
                CallManager.shared.reportIncomingCall(uuid: UUID(), callerName: raw.senderName)
            }
            return

        case kCallAcceptSignal:
            print("[WebSocketManager] CALL_ACCEPT — call connected")
            DispatchQueue.main.async { self.currentCallState = .inCall }
            return

        case kCallEndSignal:
            // Remote peer ended the call.
            print("[WebSocketManager] CALL_END from '\(raw.senderName)'")
            DispatchQueue.main.async {
                // Caller generates the log; callee just resets.
                self.terminateCall(reason: "Ended", senderId: raw.senderName, senderName: raw.senderName)
                CallManager.shared.endActiveCall()
            }
            return

        case kCallDeclineSignal:
            // Receiver declined the ringing call.
            print("[WebSocketManager] CALL_DECLINE from '\(raw.senderName)'")
            DispatchQueue.main.async {
                self.terminateCall(reason: "Declined", senderId: raw.senderName, senderName: raw.senderName)
                CallManager.shared.endActiveCall()
            }
            return

        default:
            break
        }

        // ── Call-log card (plain text, sent by caller) ────────────────────────
        if raw.text.hasPrefix(kCallLogPrefix) {
            let logMessage = ChatMessage(
                id: raw.id, senderId: raw.senderId,
                senderName: raw.senderName, text: raw.text, timestamp: raw.timestamp
            )
            DispatchQueue.main.async { self.messages.append(logMessage) }
            return
        }

        // ── Regular encrypted chat message ────────────────────────────────────
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
        let isSignal  = kAllSignals.contains(text)
        let isCallLog = text.hasPrefix(kCallLogPrefix)

        let wireText: String
        if isSignal || isCallLog {
            wireText = text   // plain text — no encryption
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

        if text == kCallInviteSignal {
            DispatchQueue.main.async { self.isCaller = true }
        }

        // Append locally for non-signal messages (chat + call-log cards).
        guard !isSignal else { return }
        let local = ChatMessage(senderId: senderId, senderName: senderName, text: text)
        DispatchQueue.main.async { self.messages.append(local) }
    }

    // MARK: - Terminate Call (centralised)

    /// Single entry point for ending a call from any trigger (button tap, remote signal).
    /// Only the **caller** (`isCaller == true`) generates and broadcasts the [[CALL_LOG]] card.
    ///
    /// - Parameters:
    ///   - reason:     "Ended" | "Declined" | "Missed" — determines the log card text.
    ///   - senderId / senderName: identity to stamp on the log message (caller's identity).
    func terminateCall(reason: String, senderId: String, senderName: String) {
        defer {
            // Always reset call state regardless of caller role.
            currentCallState = .idle
            activeCallPartnerName = ""
            callStartTime = nil
            isCaller = false
        }

        guard isCaller else {
            print("[WebSocketManager] terminateCall: callee side — resetting state only")
            return
        }

        // Build the log text based on reason and previous state.
        let logText: String
        switch reason {
        case "Ended":
            // Call was answered and connected — calculate real duration.
            let secs: Int
            if let start = callStartTime {
                secs = max(0, Int(Date().timeIntervalSince(start)))
            } else {
                secs = 0
            }
            let formatted = String(format: "%02d:%02d", secs / 60, secs % 60)
            logText = "\(kCallLogPrefix):Ended:\(formatted)"

        case "Declined":
            logText = "\(kCallLogPrefix):Declined"

        default:
            // "Missed" or any unrecognised reason.
            logText = "\(kCallLogPrefix):Missed"
        }

        print("[WebSocketManager] terminateCall: caller generating log '\(logText)'")
        sendMessage(text: logText, senderId: senderId, senderName: senderName)
    }
}
