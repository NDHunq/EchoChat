//
//  ChatListViewModel.swift
//  EchoChat
//
//  ViewModel for ChatListView. Provides the list of active conversations.
//

import Foundation
import Combine

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = ChatListViewModel.mockConversations

    // MARK: - Mock Data

    private static let mockConversations: [Conversation] = [
        Conversation(participantName: "Alice Johnson",  avatarSystemImage: "person.circle.fill", lastMessage: "Hey, are you free tonight?",         timestamp: "9:41 AM"),
        Conversation(participantName: "Bob Smith",      avatarSystemImage: "person.circle",       lastMessage: "Got your message, will reply soon.", timestamp: "Yesterday"),
        Conversation(participantName: "Carol Williams", avatarSystemImage: "person.crop.circle",  lastMessage: "Let's sync up on the project.",     timestamp: "Mon"),
        Conversation(participantName: "David Lee",      avatarSystemImage: "person.circle.fill",  lastMessage: "Thanks for the update!",             timestamp: "Sun"),
        Conversation(participantName: "Eva Martinez",   avatarSystemImage: "person.circle",       lastMessage: "Can you send me the file?",          timestamp: "Sat"),
        Conversation(participantName: "Frank Chen",     avatarSystemImage: "person.crop.circle",  lastMessage: "Sure, sounds good to me.",           timestamp: "Fri"),
    ]

    // TODO: Replace with a real network/database fetch.
    func loadConversations() {
        // Future: fetch conversations from API / local cache.
    }
}
