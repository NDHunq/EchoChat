//
//  CallView.swift
//  EchoChat
//
//  Full call-lifecycle screen: Calling → Ringing → In Call → Ended
//

import SwiftUI
import Combine

struct CallView: View {
    @ObservedObject var webSocketManager: WebSocketManager
    /// The current user's identity (to send signals as).
    let currentUser: String

    // MARK: - Timer (in-call duration)
    @State private var secondsElapsed: Int = 0
    @State private var timerRunning: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed helpers

    private var partnerName: String {
        webSocketManager.activeCallPartnerName.isEmpty
            ? "Unknown"
            : webSocketManager.activeCallPartnerName
    }

    private var statusText: String {
        switch webSocketManager.currentCallState {
        case .calling:  return "Calling…"
        case .ringing:  return "Incoming Call"
        case .inCall:   return formattedDuration
        case .idle:     return "Call Ended"
        }
    }

    private var formattedDuration: String {
        let m = secondsElapsed / 60
        let s = secondsElapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    // Avatar color — deterministic from name
    private var avatarColor: Color {
        let colors: [Color] = [.indigo, .teal, .orange, .pink, .purple, .cyan]
        let idx = abs(partnerName.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % colors.count
        return colors[idx]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────────
            LinearGradient(
                colors: [Color(.systemIndigo).opacity(0.9), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Avatar + Name ─────────────────────────────────────────
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(avatarColor.opacity(0.3))
                            .frame(width: 110, height: 110)
                        Text(String(partnerName.prefix(1).uppercased()))
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(partnerName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Spacer()

                // ── Call Controls ─────────────────────────────────────────
                Group {
                    switch webSocketManager.currentCallState {

                    case .ringing:
                        // Incoming: Accept + Decline
                        HStack(spacing: 60) {
                            CallButton(symbol: "phone.down.fill", tint: .red, label: "Decline") {
                                endCall()
                            }
                            CallButton(symbol: "phone.fill", tint: .green, label: "Accept") {
                                acceptCall()
                            }
                        }

                    case .calling, .inCall:
                        // Outgoing / connected: End button only
                        CallButton(symbol: "phone.down.fill", tint: .red, label: "End Call") {
                            endCall()
                        }

                    case .idle:
                        // Call ended — auto-dismiss after brief pause
                        Text("Call Ended")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                            }
                    }
                }
                .padding(.bottom, 70)
            }
        }
        // ── Timer ─────────────────────────────────────────────────────────
        .onReceive(timer) { _ in
            guard timerRunning else { return }
            secondsElapsed += 1
        }
        // Start timer when call is accepted
        .onChange(of: webSocketManager.currentCallState) { state in
            if state == .inCall {
                secondsElapsed = 0
                timerRunning = true
            } else if state == .idle {
                timerRunning = false
            }
        }
        // Remote ended the call → dismiss
        .onChange(of: webSocketManager.currentCallState) { state in
            if state == .idle { dismiss() }
        }
    }

    // MARK: - Actions

    private func acceptCall() {
        // Callee accepts — tell caller the call is connected.
        webSocketManager.sendMessage(
            text: kCallAcceptSignal,
            senderId: currentUser,
            senderName: currentUser
        )
        webSocketManager.currentCallState = .inCall
        secondsElapsed = 0
        timerRunning = true
    }

    private func endCall() {
        timerRunning = false

        if webSocketManager.isCaller {
            // ── Caller ends the call ──────────────────────────────────────
            // Determine log reason before state is reset inside terminateCall.
            let reason: String
            switch webSocketManager.currentCallState {
            case .inCall:   reason = "Ended"
            case .calling:  reason = "Missed"   // rang but never answered
            default:        reason = "Missed"
            }
            // Generate + broadcast the [[CALL_LOG]] card, then reset state.
            webSocketManager.terminateCall(
                reason: reason,
                senderId: currentUser,
                senderName: currentUser
            )
            // Notify the remote peer to close their CallView.
            webSocketManager.sendMessage(
                text: kCallEndSignal,
                senderId: currentUser,
                senderName: currentUser
            )
        } else {
            // ── Callee ends / declines the call ──────────────────────────
            let signal = webSocketManager.currentCallState == .ringing
                ? kCallDeclineSignal    // declined before answering
                : kCallEndSignal        // ended after answering
            webSocketManager.sendMessage(
                text: signal,
                senderId: currentUser,
                senderName: currentUser
            )
            // Callee just resets local state — no log generation.
            webSocketManager.currentCallState = .idle
            webSocketManager.activeCallPartnerName = ""
            webSocketManager.callStartTime = nil
            webSocketManager.isCaller = false
        }

        CallManager.shared.endActiveCall()
        dismiss()
    }
}

// MARK: - Reusable Call Button

private struct CallButton: View {
    let symbol: String
    let tint: Color
    let label: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(tint)
                    .clipShape(Circle())
                    .shadow(color: tint.opacity(0.5), radius: 10, y: 4)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

#Preview {
    let wsm = WebSocketManager()
    wsm.activeCallPartnerName = "Alice"
    wsm.currentCallState = .calling
    return CallView(webSocketManager: wsm, currentUser: "Bob")
}
