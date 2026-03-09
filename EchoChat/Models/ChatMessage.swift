//
//  ChatMessage.swift
//  EchoChat
//
//  Wire-level chat message model. Conforms to Codable for JSON
//  serialization over WebSocket and Identifiable for SwiftUI lists.
//

import Foundation

struct ChatMessage: Codable, Identifiable {
    /// Local-only UUID for SwiftUI list identity. Not sent over the wire.
    let id: UUID
    /// Unique identifier of the sender (e.g. "sim_1").
    let senderId: String
    /// Display name shown in the UI.
    let senderName: String
    /// The message body.
    let text: String
    /// ISO 8601 timestamp string, e.g. "2026-03-09T10:30:00Z".
    let timestamp: String

    // Exclude `id` from JSON encoding/decoding since it is local-only.
    enum CodingKeys: String, CodingKey {
        case senderId, senderName, text, timestamp
    }

    init(id: UUID = UUID(),
         senderId: String,
         senderName: String,
         text: String,
         timestamp: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
    }

    // Custom decoder: generate a fresh local UUID on decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.senderId   = try container.decode(String.self, forKey: .senderId)
        self.senderName = try container.decode(String.self, forKey: .senderName)
        self.text       = try container.decode(String.self, forKey: .text)
        self.timestamp  = try container.decode(String.self, forKey: .timestamp)
    }
}
