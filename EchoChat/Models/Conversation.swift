//
//  Conversation.swift
//  EchoChat
//
//  Model representing a chat conversation entry shown in the chat list.
//

import Foundation

struct Conversation: Identifiable {
    let id: UUID
    let participantName: String
    let avatarSystemImage: String
    let lastMessage: String
    let timestamp: String

    init(
        id: UUID = UUID(),
        participantName: String,
        avatarSystemImage: String,
        lastMessage: String,
        timestamp: String
    ) {
        self.id = id
        self.participantName = participantName
        self.avatarSystemImage = avatarSystemImage
        self.lastMessage = lastMessage
        self.timestamp = timestamp
    }
}
