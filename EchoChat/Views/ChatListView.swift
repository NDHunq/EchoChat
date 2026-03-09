//
//  ChatListView.swift
//  EchoChat
//
//  Displays the list of active conversations.
//  Data is provided by ChatListViewModel (MVVM).
//

import SwiftUI

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: conversation.avatarSystemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.participantName)
                        .font(.headline)
                    Spacer()
                    Text(conversation.timestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ChatListView

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink(destination: ChatView(conversationTitle: conversation.participantName)) {
                ConversationRow(conversation: conversation)
            }
        }
        .listStyle(.plain)
        .navigationTitle("EchoChat")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        ChatListView()
    }
}
