//
//  CallManager.swift
//  EchoChat
//
//  Integrates CallKit to present a native incoming-call UI.
//  Acts as the bridge between our WebSocket signalling layer and the system.
//

import Foundation
import CallKit
import AVFoundation

// MARK: - Notifications (Simulator fallback)

let kIncomingCallNotification  = Notification.Name("EchoChat.IncomingCall")
let kIncomingCallCallerNameKey = "callerName"

// MARK: - CallManager

final class CallManager: NSObject {

    // MARK: Singleton
    static let shared = CallManager()

    // MARK: WebSocket bridge
    /// Injected by the scene/view that owns WebSocketManager.
    /// CallManager uses this to send signals when native CallKit buttons are tapped.
    weak var webSocketManager: WebSocketManager?
    /// The current user's senderId/senderName — set alongside webSocketManager.
    var currentUser: String = ""

    // MARK: Private
    private let provider: CXProvider
    private let callController = CXCallController()
    private(set) var activeCallUUID: UUID?

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Init

    private override init() {
        let config = CXProviderConfiguration(localizedName: "EchoChat")
        config.supportsVideo            = true
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes     = [.generic]
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: .main)
    }

    // MARK: - Report Incoming Call

    func reportIncomingCall(uuid: UUID, callerName: String) {
        activeCallUUID = uuid

        if Self.isSimulator {
            print("[CallManager] Simulator — posting in-app notification")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: kIncomingCallNotification,
                    object: nil,
                    userInfo: [kIncomingCallCallerNameKey: callerName]
                )
            }
            return
        }

        let update = CXCallUpdate()
        update.remoteHandle        = CXHandle(type: .generic, value: callerName)
        update.localizedCallerName = callerName
        update.hasVideo            = true
        update.supportsHolding     = false

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                print("[CallManager] reportIncomingCall failed: \(error.localizedDescription)")
                self.activeCallUUID = nil
            } else {
                print("[CallManager] Incoming call reported — caller: \(callerName)")
            }
        }
    }

    // MARK: - End Active Call (programmatic)

    func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
        callController.request(transaction) { error in
            if let error { print("[CallManager] endActiveCall error: \(error.localizedDescription)") }
        }
        activeCallUUID = nil
    }
}

// MARK: - CXProviderDelegate

extension CallManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        print("[CallManager] providerDidReset")
        activeCallUUID = nil
    }

    /// User tapped "Accept" on the native CallKit UI (real device only).
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[CallManager] CXAnswerCallAction — sending CALL_ACCEPT over WebSocket")

        // 1. Tell the remote caller that we accepted.
        webSocketManager?.sendMessage(
            text: kCallAcceptSignal,
            senderId: currentUser,
            senderName: currentUser
        )
        // 2. Update local call state so CallView transitions to in-call UI.
        DispatchQueue.main.async {
            self.webSocketManager?.currentCallState = .inCall
        }
        // 3. Fulfil the CallKit action — required or the system will time out.
        action.fulfill()
    }

    /// User tapped "Decline" or "End" on the native CallKit UI (real device only).
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallManager] CXEndCallAction — sending CALL_END over WebSocket")

        // 1. Notify the remote peer that the call is over.
        webSocketManager?.sendMessage(
            text: kCallEndSignal,
            senderId: currentUser,
            senderName: currentUser
        )
        // 2. Reset local state.
        DispatchQueue.main.async {
            self.webSocketManager?.currentCallState = .idle
            self.webSocketManager?.activeCallPartnerName = ""
        }
        activeCallUUID = nil
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallManager] Audio session activated")
        // TODO: Start WebRTC audio track.
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallManager] Audio session deactivated")
        // TODO: Stop WebRTC audio track.
    }
}
