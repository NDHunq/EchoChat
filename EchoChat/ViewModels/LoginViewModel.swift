//
//  LoginViewModel.swift
//  EchoChat
//
//  ViewModel for LoginView. Handles credential state and login action.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    // MARK: - Validation

    var isInputValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    // MARK: - Login

    func login() {
        guard isInputValid else {
            errorMessage = "Please enter your email and password."
            return
        }

        isLoading = true
        errorMessage = nil

        // TODO: Replace with real authentication (e.g., OAuth2 / JWT via API call).
        // TODO: Persist authentication token securely in Keychain.
        // TODO: Handle login errors and show appropriate messages.

        // Simulated instant login for UI development.
        isLoggedIn = true
        isLoading = false
    }
}
