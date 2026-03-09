//
//  EchoChatApp.swift
//  EchoChat
//
//  App entry point. Handles the full authentication flow:
//    1. LockScreenView  — biometric / passcode gate
//    2. LoginView       — first-launch identity setup (saved to Keychain)
//    3. ChatListView    — main app (returning user, already in Keychain)
//

import SwiftUI

@main
struct EchoChatApp: App {
    @StateObject private var authManager = BiometricAuthManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                RootView()
            } else {
                LockScreenView(authManager: authManager)
            }
        }
    }
}

// MARK: - RootView

/// Decides whether to show LoginView (new user) or ChatListView (returning user)
/// by checking for a saved identity in the Keychain.
struct RootView: View {
    private var hasStoredUser: Bool {
        KeychainManager.shared.load(key: KeychainManager.currentUserKey) != nil
    }

    var body: some View {
        if hasStoredUser {
            // Returning user — go straight to the chat list.
            NavigationStack {
                ChatListView()
            }
        } else {
            // First launch — user must set up their identity.
            LoginView()
        }
    }
}
