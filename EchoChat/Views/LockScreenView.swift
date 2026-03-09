//
//  LockScreenView.swift
//  EchoChat
//
//  Shown at app launch when the user has not yet authenticated via biometrics.
//  Automatically triggers authentication on appear.
//

import SwiftUI

struct LockScreenView: View {
    @ObservedObject var authManager: BiometricAuthManager

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemIndigo), Color(.systemBlue).opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // MARK: App Icon + Name
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.white)

                    Text("EchoChat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Your messages are end-to-end encrypted")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // MARK: Error message (if any)
                if let error = authManager.authError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // MARK: Unlock Button
                Button(action: authManager.authenticate) {
                    HStack(spacing: 10) {
                        Image(systemName: authManager.biometricSymbol)
                            .font(.title3)
                        Text(authManager.biometricLabel)
                            .font(.headline)
                    }
                    .foregroundStyle(Color(.systemIndigo))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        // Automatically prompt on first appearance.
        .onAppear {
            authManager.authenticate()
        }
    }
}

#Preview {
    LockScreenView(authManager: BiometricAuthManager())
}
