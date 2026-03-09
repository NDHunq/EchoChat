//
//  ChatView.swift
//  EchoChat
//
//  Messaging interface. Connects to ws://localhost:8080 via WebSocketManager.
//  Sent messages (senderId == currentUser) appear on the right in blue;
//  received messages appear on the left in gray.
//

import SwiftUI

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let currentUser: String

    private var isMine: Bool { message.senderId == currentUser }

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if !isMine {
                Text(message.senderName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            HStack {
                if isMine { Spacer(minLength: 60) }

                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(isMine ? .white : Color(.label))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if !isMine { Spacer(minLength: 60) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

// MARK: - ChatView

struct ChatView: View {
    let conversationTitle: String

    @StateObject private var webSocketManager = WebSocketManager()
    @AppStorage("currentUser") private var currentUser: String = ""
    @State private var newMessage: String = ""
    @State private var isCallPresented: Bool = false

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Messages Scroll Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(webSocketManager.messages) { message in
                            MessageBubble(message: message, currentUser: currentUser)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: webSocketManager.messages.count) { _ in
                    if let last = webSocketManager.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // MARK: Input Bar
            HStack(spacing: 12) {
                TextField("Type message", text: $newMessage)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                    .onSubmit { send() }

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(
                            newMessage.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray
                                : Color.accentColor
                        )
                        .clipShape(Circle())
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Connection status indicator
                    Circle()
                        .fill(webSocketManager.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    // Phone call button
                    Button {
                        isCallPresented = true
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .onAppear {
            webSocketManager.connect()
        }
        .onDisappear {
            webSocketManager.disconnect()
        }
        .fullScreenCover(isPresented: $isCallPresented) {
            CallView(calleeName: conversationTitle)
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
}

#Preview {
    NavigationStack {
        ChatView(conversationTitle: "Alice Johnson")
    }
}
