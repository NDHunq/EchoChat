//
//  CallView.swift
//  EchoChat
//
//  Simulated in-call screen. Shown when the user taps the phone icon in ChatView.
//

import SwiftUI

struct CallView: View {
    @StateObject private var viewModel: CallViewModel
    @Environment(\.dismiss) private var dismiss

    init(calleeName: String) {
        _viewModel = StateObject(wrappedValue: CallViewModel(calleeName: calleeName))
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemIndigo).opacity(0.85), Color(.systemBlue).opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: Avatar + Name
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(viewModel.calleeName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    // Status label
                    Group {
                        switch viewModel.callState {
                        case .connecting:
                            Text("Connecting…")
                                .foregroundStyle(.white.opacity(0.75))
                        case .active:
                            Text(viewModel.formattedDuration)
                                .foregroundStyle(.white.opacity(0.9))
                                .monospacedDigit()
                        case .ended:
                            Text("Call ended")
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .font(.subheadline)
                }

                Spacer()

                // MARK: Control Buttons
                HStack(spacing: 48) {
                    // Mute
                    CallControlButton(
                        systemImage: viewModel.isMuted ? "mic.slash.fill" : "mic.fill",
                        label: viewModel.isMuted ? "Unmute" : "Mute",
                        tint: viewModel.isMuted ? .white : .white.opacity(0.7)
                    ) {
                        viewModel.toggleMute()
                    }

                    // End call
                    CallControlButton(
                        systemImage: "phone.down.fill",
                        label: "End",
                        tint: .white,
                        background: .red,
                        size: 68
                    ) {
                        viewModel.endCall()
                        dismiss()
                    }

                    // Speaker
                    CallControlButton(
                        systemImage: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                        label: "Speaker",
                        tint: viewModel.isSpeakerOn ? .white : .white.opacity(0.7)
                    ) {
                        viewModel.toggleSpeaker()
                    }
                }
                .padding(.bottom, 60)
            }
        }
        // Auto-dismiss if call ends programmatically
        .onChange(of: viewModel.callState) { state in
            if state == .ended { dismiss() }
        }
    }
}

// MARK: - Reusable Control Button

private struct CallControlButton: View {
    let systemImage: String
    let label: String
    var tint: Color = .white
    var background: Color = Color.white.opacity(0.2)
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .background(background)
                    .clipShape(Circle())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

#Preview {
    CallView(calleeName: "Alice Johnson")
}
