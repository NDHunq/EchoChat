//
//  ChatView.swift
//  EchoChat
//
//  Professional iMessage/WhatsApp-style chat interface.
//  Bubble rendering is handled by MessageBubbleView.swift.
//

import SwiftUI

// MARK: - ChatView

struct ChatView: View {
    let conversationTitle: String

    @StateObject private var webSocketManager = WebSocketManager()
    @State private var newMessage: String = ""
    @FocusState private var inputFocused: Bool

    private var currentUser: String {
        KeychainManager.shared.load(key: KeychainManager.currentUserKey) ?? "Unknown"
    }

    /// Drive the call screen from call state so both outgoing and incoming
    /// calls open CallView automatically.
    private var isCallActive: Bool {
        webSocketManager.currentCallState != .idle
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(webSocketManager.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: message.senderId == currentUser
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: webSocketManager.messages.count) { _ in
                    guard let last = webSocketManager.messages.last else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // MARK: Input Bar
            VStack(spacing: 0) {
                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    // Text field
                    TextField("iMessage", text: $newMessage, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .focused($inputFocused)
                        .onSubmit { send() }

                    // Send button
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(
                                    newMessage.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color(.systemGray3)
                                    : Color.accentColor
                                )
                            )
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                    .animation(.easeInOut(duration: 0.15), value: newMessage.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color(.secondarySystemBackground)
                        .shadow(color: .black.opacity(0.07), radius: 8, y: -3)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    // Connection status dot
                    Circle()
                        .fill(webSocketManager.isConnected ? Color.green : Color(.systemGray3))
                        .frame(width: 8, height: 8)

                    // Video call button — sends CALL_RINGING signal to peers
                    Button(action: startCall) {
                        Image(systemName: "video.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .onAppear {
            webSocketManager.connect()
            // Bridge CallManager to this WebSocketManager so native CallKit
            // button taps (Answer / End on real device) can send WebSocket signals.
            CallManager.shared.webSocketManager = webSocketManager
            CallManager.shared.currentUser = currentUser
        }
        .onDisappear { webSocketManager.disconnect() }
        // Simulator fallback: CallManager posts a notification instead of showing
        // native CallKit UI → we set state to .ringing which triggers fullScreenCover.
        .onReceive(NotificationCenter.default.publisher(for: kIncomingCallNotification)) { notification in
            let caller = notification.userInfo?[kIncomingCallCallerNameKey] as? String ?? conversationTitle
            webSocketManager.activeCallPartnerName = caller
            webSocketManager.currentCallState = .ringing
        }
        // Single source of truth: show CallView whenever a call is active.
        .fullScreenCover(isPresented: Binding(
            get: { isCallActive },
            set: { if !$0 {
                webSocketManager.currentCallState = .idle
                webSocketManager.activeCallPartnerName = ""
            }}
        )) {
            CallView(webSocketManager: webSocketManager, currentUser: currentUser)
        }
    }

    // MARK: - Send

    private func send() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        webSocketManager.sendMessage(
            text: trimmed,
            senderId: currentUser,
            senderName: currentUser
        )
        newMessage = ""
    }

    // MARK: - Start Call

    private func startCall() {
        webSocketManager.activeCallPartnerName = conversationTitle
        webSocketManager.currentCallState = .calling
        webSocketManager.sendMessage(
            text: kCallInviteSignal,
            senderId: currentUser,
            senderName: currentUser
        )
        // No need to set isCallPresented — fullScreenCover reacts to currentCallState != .idle
    }
}

#Preview {
    NavigationStack {
        ChatView(conversationTitle: "Alice Johnson")
    }
}
