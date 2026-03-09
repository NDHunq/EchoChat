//
//  LoginView.swift
//  EchoChat
//
//  Login screen for MiniOTTChat. Accepts email and password,
//  then navigates to the conversation list.
//  State is managed by LoginViewModel (MVVM).
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @AppStorage("currentUser") private var currentUser: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // MARK: - Logo / Title
                VStack(spacing: 8) {
                    Image(systemName: "message.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.tint)

                    Text("EchoChat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                // MARK: - Input Fields
                VStack(spacing: 16) {
                    TextField("Your name", text: $viewModel.email)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    SecureField("Password", text: $viewModel.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                // MARK: - Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // MARK: - Navigation Trigger
                NavigationLink(
                    destination: ChatListView(),
                    isActive: $viewModel.isLoggedIn
                ) {
                    EmptyView()
                }

                // MARK: - Login Button
                Button {
                    // Persist the entered name so ChatView can read it via @AppStorage
                    currentUser = viewModel.email.trimmingCharacters(in: .whitespaces)
                    viewModel.login()
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Login")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isInputValid ? Color.accentColor : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!viewModel.isInputValid || viewModel.isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    LoginView()
}
