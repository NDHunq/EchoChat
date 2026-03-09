//
//  Message.swift
//  EchoChat
//
//  Data model representing a single chat message.
//

import Foundation

struct Message: Identifiable {
    let id: UUID
    let text: String
    /// `true` when this message was sent by the current user.
    let isSentByMe: Bool
    /// Display name of the sender (used for group chats / received messages).
    let senderName: String

    init(
        id: UUID = UUID(),
        text: String,
        isSentByMe: Bool = true,
        senderName: String = "Me"
    ) {
        self.id = id
        self.text = text
        self.isSentByMe = isSentByMe
        self.senderName = senderName
    }
}
