//
//  WebSocketManager.swift
//  EchoChat
//

import Foundation
import Combine
import UIKit

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
let kTypingSignal       = "[[TYPING]]"

let kCallRingingSignal  = kCallInviteSignal   // legacy alias

private let kAllSignals: Set<String> = [
    kCallInviteSignal, kCallAcceptSignal, kCallEndSignal, kCallDeclineSignal, kTypingSignal
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

    // MARK: Typing Indicator
    @Published var isPartnerTyping: Bool = false
    @Published var typingPartnerName: String = ""
    private var typingTimer: Timer?
    private var lastTypingSignalDate: Date?

    // MARK: Call Tracking
    var callStartTime: Date? = nil
    var isCaller: Bool = false

    // MARK: Private
    private var task: URLSessionWebSocketTask?
    private let url = URL(string: "ws://localhost:8080")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Connect / Disconnect

    func connect() {
        task = URLSession.shared.webSocketTask(with: url)
        // Increase the receive buffer to 50 MB so encrypted image payloads
        // don't cause an immediate disconnect (default limit is 1 MB).
        task?.maximumMessageSize = 50 * 1024 * 1024
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
                case .string(let json):
                    self.handleIncoming(jsonString: json)
                case .data(let data):
                    if let json = String(data: data, encoding: .utf8) {
                        self.handleIncoming(jsonString: json)
                    } else {
                        print("[WebSocketManager] Received non-UTF8 data frame — skipping")
                    }
                @unknown default:
                    break
                }
                // Always re-arm the listener after a successful receive,
                // regardless of whether handleIncoming succeeded.
                self.receiveMessages()

            case .failure(let error):
                let nsError = error as NSError
                // URLSessionWebSocketTask reports cancellation as NSURLErrorCancelled (-999).
                // Don't retry in that case — the user deliberately disconnected.
                if nsError.code == NSURLErrorCancelled {
                    print("[WebSocketManager] Socket cancelled — stopping receive loop")
                    return
                }
                print("[WebSocketManager] Receive error: \(error.localizedDescription) — retrying loop")
                DispatchQueue.main.async { self.isConnected = false }
                // Retry so a transient frame error doesn't kill the whole session.
                self.receiveMessages()
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
            print("[WebSocketManager] CALL_DECLINE from '\(raw.senderName)'")
            DispatchQueue.main.async {
                self.terminateCall(reason: "Declined", senderId: raw.senderName, senderName: raw.senderName)
                CallManager.shared.endActiveCall()
            }
            return

        case kTypingSignal:
            DispatchQueue.main.async {
                self.typingPartnerName = raw.senderName
                self.isPartnerTyping = true
                // Reset the auto-hide timer every time a typing signal arrives.
                self.typingTimer?.invalidate()
                self.typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.isPartnerTyping = false
                        self?.typingPartnerName = ""
                    }
                }
            }
            return  // ephemeral — never stored or decrypted

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

        // Decrypt the image payload if present.
        var decryptedImage: String? = nil
        if let encryptedImage = raw.imageBase64 {
            decryptedImage = CryptoManager.shared.decrypt(base64String: encryptedImage)
            if decryptedImage == nil {
                print("[WebSocketManager] Image decryption failed — showing message without image")
            }
        }

        let chatMessage = ChatMessage(
            id: raw.id, senderId: raw.senderId,
            senderName: raw.senderName, text: decryptedText,
            timestamp: raw.timestamp, imageBase64: decryptedImage
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

    // MARK: - Send Image

    /// Compresses, encrypts and sends a UIImage over WebSocket.
    /// The sender sees their own image immediately (plain Base64 appended locally).
    /// The receiver gets the encrypted payload and decrypts it in handleIncoming().
    func sendImage(image: UIImage, senderId: String, senderName: String) {
        // 1. Compress to JPEG to keep the WebSocket payload manageable.
        guard let imageData = image.jpegData(compressionQuality: 0.3) else {
            print("[WebSocketManager] sendImage: JPEG compression failed")
            return
        }

        // 2. Plain Base64 — used for local display only.
        let plainBase64 = imageData.base64EncodedString()

        // 3. Encrypt the Base64 string before sending over the wire.
        guard let encryptedBase64 = CryptoManager.shared.encrypt(message: plainBase64) else {
            print("[WebSocketManager] sendImage: encryption failed")
            return
        }

        // 4. Encrypt the text field too ("[Image]" placeholder).
        guard let encryptedText = CryptoManager.shared.encrypt(message: "[Image]") else { return }

        // 5. Build and send the wire message (encrypted image + encrypted text).
        let wireMessage = ChatMessage(
            senderId: senderId, senderName: senderName,
            text: encryptedText, imageBase64: encryptedBase64
        )
        guard let data = try? encoder.encode(wireMessage),
              let json = String(data: data, encoding: .utf8) else { return }

        task?.send(.string(json)) { error in
            if let error { print("[WebSocketManager] sendImage error: \(error.localizedDescription)") }
        }

        // 6. Append locally with PLAIN Base64 so sender sees their image immediately.
        let localMessage = ChatMessage(
            senderId: senderId, senderName: senderName,
            text: "[Image]", imageBase64: plainBase64
        )
        DispatchQueue.main.async { self.messages.append(localMessage) }
    }

    // MARK: - Typing Signal

    /// Sends a [[TYPING]] signal at most once every 2 seconds (debounced).
    /// The signal is plain text, ephemeral — never encrypted or stored.
    func sendTypingSignal(senderId: String, senderName: String) {
        let now = Date()
        if let last = lastTypingSignalDate, now.timeIntervalSince(last) < 2.0 { return }
        lastTypingSignalDate = now

        let wireMessage = ChatMessage(senderId: senderId, senderName: senderName, text: kTypingSignal)
        guard let data = try? encoder.encode(wireMessage),
              let json = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(json)) { error in
            if let error { print("[WebSocketManager] Typing signal error: \(error.localizedDescription)") }
        }
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
