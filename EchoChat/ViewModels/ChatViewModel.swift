//
//  ChatViewModel.swift
//  EchoChat
//
//  ViewModel for ChatView. Manages the messages list and
//  handles sending new messages.
//

import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessage: String = ""

    // MARK: - Send Message

    /// Appends the composed message to the local array, then resets the input field.
    func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // TODO: Encrypt the message payload before sending (e.g., end-to-end encryption).
        // TODO: Serialize the encrypted message to the agreed wire format (e.g., Protobuf / JSON).
        // TODO: Send the serialized payload over the network (WebSocket / HTTP POST).
        // TODO: Handle server acknowledgment and update message delivery status (sent/delivered/read).

        let message = Message(text: trimmed, isSentByMe: true, senderName: "Me")
        messages.append(message)
        newMessage = ""
    }

    /// Simulates receiving an incoming message (for local preview / testing).
    func receiveMessage(text: String, from sender: String = "Alice") {
        let message = Message(text: text, isSentByMe: false, senderName: sender)
        messages.append(message)
    }
}
