//
//  CallViewModel.swift
//  EchoChat
//
//  ViewModel for CallView. Manages call state (connecting → active → ended).
//

import Foundation
import Combine

@MainActor
final class CallViewModel: ObservableObject {
    enum CallState {
        case connecting
        case active
        case ended
    }

    @Published var callState: CallState = .connecting
    @Published var callDurationSeconds: Int = 0
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = false

    let calleeName: String
    private var timer: AnyCancellable?

    init(calleeName: String) {
        self.calleeName = calleeName
        simulateConnect()
    }

    // MARK: - Formatted duration (MM:SS)

    var formattedDuration: String {
        let minutes = callDurationSeconds / 60
        let seconds = callDurationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    func toggleMute() {
        isMuted.toggle()
        // TODO: Mute/unmute local audio track via WebRTC.
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        // TODO: Switch audio output route (earpiece ↔ speaker).
    }

    func endCall() {
        timer?.cancel()
        callState = .ended
        // TODO: Send call-end signal over the network (WebSocket / SIP BYE).
    }

    // MARK: - Private

    /// Simulates a 2-second "connecting" phase before the call becomes active.
    private func simulateConnect() {
        // TODO: Replace with real call signalling (WebRTC offer/answer exchange).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.callState = .active
            self.startTimer()
        }
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.callDurationSeconds += 1
            }
    }
}
