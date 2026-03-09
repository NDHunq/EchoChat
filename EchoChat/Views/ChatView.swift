//
//  ChatView.swift
//  EchoChat
//
//  Professional iMessage/WhatsApp-style chat interface.
//

import SwiftUI

// MARK: - Timestamp Formatter

extension String {
    /// Converts an ISO 8601 timestamp string into a human-readable time string.
    /// - Returns: e.g. "10:30 AM", "Yesterday", or "Mon" depending on how old the message is.
    var formattedMessageTime: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: self) ?? ISO8601DateFormatter().date(from: self)
        guard let date else { return self }

        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let f = DateFormatter()
            f.dateFormat = "EEE"          // Mon, Tue …
            return f.string(from: date)
        }
    }
}

// MARK: - Avatar View

private struct AvatarView: View {
    let name: String
    /// Deterministic pastel color derived from the name string.
    private var color: Color {
        let colors: [Color] = [.indigo, .teal, .orange, .pink, .purple, .green, .cyan]
        let index = abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % colors.count
        return colors[index]
    }
    private var initial: String {
        String(name.prefix(1).uppercased())
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 34, height: 34)
            Text(initial)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Custom Bubble Shape

/// Bubble with one less-rounded corner (iMessage-style tail).
private struct BubbleShape: Shape {
    let isCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tailR: CGFloat = 6      // smaller radius on tail corner
        var path = Path()

        if isCurrentUser {
            // Outgoing: small radius on bottom-right
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tailR))
            path.addArc(center: CGPoint(x: rect.maxX - tailR, y: rect.maxY - tailR),
                        radius: tailR, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            // Incoming: small radius on bottom-left
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + tailR, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + tailR, y: rect.maxY - tailR),
                        radius: tailR, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - MessageBubbleView

struct MessageBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Incoming avatar on the left
                AvatarView(name: message.senderName)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3) {
                // Sender name (incoming only)
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                // Bubble
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isCurrentUser ? .white : Color(.label))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        BubbleShape(isCurrentUser: isCurrentUser)
                            .fill(isCurrentUser ? Color.accentColor : Color(.secondarySystemBackground))
                    )

                // Timestamp
                Text(message.timestamp.formattedMessageTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(isCurrentUser ? .trailing : .leading, 4)
            }

            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }
}

// MARK: - ChatView

struct ChatView: View {
    let conversationTitle: String

    @StateObject private var webSocketManager = WebSocketManager()
    @State private var newMessage: String = ""
    @State private var isCallPresented: Bool = false
    @State private var incomingCallerName: String = ""
    @FocusState private var inputFocused: Bool

    private var currentUser: String {
        KeychainManager.shared.load(key: KeychainManager.currentUserKey) ?? "Unknown"
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
        .onAppear { webSocketManager.connect() }
        .onDisappear { webSocketManager.disconnect() }
        // Simulator fallback: CallKit cannot show native UI on Simulator,
        // so CallManager posts a notification → present CallView in-app instead.
        .onReceive(NotificationCenter.default.publisher(for: kIncomingCallNotification)) { notification in
            let caller = notification.userInfo?[kIncomingCallCallerNameKey] as? String ?? conversationTitle
            incomingCallerName = caller
            isCallPresented = true
        }
        .fullScreenCover(isPresented: $isCallPresented) {
            CallView(calleeName: incomingCallerName.isEmpty ? conversationTitle : incomingCallerName)
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

    /// Broadcasts a [[CALL_RINGING]] signal over WebSocket so all connected
    /// peers receive a native CallKit incoming-call notification.
    /// The signal is sent unencrypted and is not shown in the chat history.
    private func startCall() {
        webSocketManager.sendMessage(
            text: kCallRingingSignal,
            senderId: currentUser,
            senderName: currentUser
        )
    }
}

#Preview {
    NavigationStack {
        ChatView(conversationTitle: "Alice Johnson")
    }
}
