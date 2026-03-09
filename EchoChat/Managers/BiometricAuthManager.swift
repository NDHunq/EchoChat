//
//  BiometricAuthManager.swift
//  EchoChat
//
//  Handles Face ID / Touch ID authentication using LocalAuthentication.
//
//  ⚠️  IMPORTANT — Info.plist requirement:
//  You MUST add the NSFaceIDUsageDescription key to your Info.plist
//  (or via Xcode: Target → Info tab → add "Privacy - Face ID Usage Description")
//  with a value such as:
//      "EchoChat uses Face ID to protect your secure messages."
//  Without this key the app will crash at runtime when Face ID is requested.
//

import Foundation
import LocalAuthentication
import Combine

final class BiometricAuthManager: ObservableObject {

    // MARK: - Published State

    /// `true` once the user has successfully authenticated in the current session.
    @Published var isAuthenticated: Bool = false
    /// Holds a human-readable error message when authentication fails.
    @Published var authError: String? = nil

    // MARK: - Biometric Type

    /// Returns the available biometric type (Face ID, Touch ID, or none).
    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// SF Symbol name matching the available biometric type.
    var biometricSymbol: String {
        switch biometricType {
        case .faceID:   return "faceid"
        case .touchID:  return "touchid"
        default:        return "lock.fill"
        }
    }

    /// Button label matching the available biometric type.
    var biometricLabel: String {
        switch biometricType {
        case .faceID:  return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default:       return "Unlock"
        }
    }

    // MARK: - Authenticate

    /// Triggers a biometric (or passcode fallback) authentication prompt.
    /// Sets `isAuthenticated = true` on the Main thread upon success.
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check whether biometrics are available on this device.
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available — fall back to device passcode.
            authenticateWithPasscode(context: context)
            return
        }

        let reason = "Unlock EchoChat to access your secure messages."

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { [weak self] success, evaluationError in
            guard let self else { return }
            Task { @MainActor in
                if success {
                    self.isAuthenticated = true
                    self.authError = nil
                } else {
                    self.isAuthenticated = false
                    self.authError = evaluationError?.localizedDescription
                        ?? "Authentication failed. Please try again."
                }
            }
        }
    }

    // MARK: - Passcode Fallback

    /// Falls back to device passcode when biometrics are unavailable or locked out.
    private func authenticateWithPasscode(context: LAContext) {
        let reason = "Enter your device passcode to unlock EchoChat."
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        ) { [weak self] success, error in
            guard let self else { return }
            Task { @MainActor in
                self.isAuthenticated = success
                self.authError = success ? nil : (error?.localizedDescription ?? "Authentication failed.")
            }
        }
    }
}
