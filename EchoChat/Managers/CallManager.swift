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

// MARK: - Call Signalling Token

/// The plain-text magic token exchanged over WebSocket to signal a call.
let kCallRingingSignal = "[[CALL_RINGING]]"

/// Posted when an incoming call arrives on Simulator (CallKit fallback).
let kIncomingCallNotification = Notification.Name("EchoChat.IncomingCall")
/// UserInfo key carrying the caller's name string.
let kIncomingCallCallerNameKey = "callerName"

// MARK: - CallManager

final class CallManager: NSObject {

    // MARK: Singleton
    static let shared = CallManager()

    // MARK: Private
    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCallUUID: UUID?

    /// `true` when running inside the iOS Simulator.
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

    /// Shows the native CallKit UI on a real device.
    /// On Simulator, falls back to an in-app notification so the UI can present CallView.
    func reportIncomingCall(uuid: UUID, callerName: String) {
        if Self.isSimulator {
            // CallKit incoming-call UI is not supported on the Simulator.
            // Post a local notification so ChatView can present the in-app CallView instead.
            print("[CallManager] Simulator detected — using in-app call UI fallback")
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
            } else {
                print("[CallManager] Incoming call reported — caller: \(callerName), uuid: \(uuid)")
                self.activeCallUUID = uuid
            }
        }
    }

    // MARK: - End Active Call

    func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        let action = CXEndCallAction(call: uuid)
        callController.request(CXTransaction(action: action)) { error in
            if let error {
                print("[CallManager] endActiveCall failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CXProviderDelegate

extension CallManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        print("[CallManager] providerDidReset — cleaning up")
        activeCallUUID = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[CallManager] Call answered — uuid: \(action.callUUID)")
        // TODO: Connect WebRTC peer connection.
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallManager] Call ended — uuid: \(action.callUUID)")
        // TODO: Close WebRTC peer connection.
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
