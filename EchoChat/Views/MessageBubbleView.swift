//
//  MessageBubbleView.swift
//  EchoChat
//
//  Chat bubble rendering for EchoChat.
//  Handles both regular text messages and [[CALL_LOG]] call-info cards.
//

import SwiftUI
import UIKit

// MARK: - Timestamp Formatter

extension String {
    /// Converts an ISO 8601 timestamp string into a human-readable time string.
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
            f.dateFormat = "EEE"
            return f.string(from: date)
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let name: String

    private var color: Color {
        let colors: [Color] = [.indigo, .teal, .orange, .pink, .purple, .green, .cyan]
        let index = abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % colors.count
        return colors[index]
    }
    private var initial: String { String(name.prefix(1).uppercased()) }

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

// MARK: - Bubble Shape

/// iMessage-style bubble: one corner has a smaller radius to form a "tail".
struct BubbleShape: Shape {
    let isCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat    = 18
        let tailR: CGFloat = 6
        var path = Path()

        if isCurrentUser {
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

// MARK: - Call Log Parsing

private enum CallLogKind {
    case missed
    case declined
    case ended(duration: String)
}

private func parseCallLog(_ text: String) -> CallLogKind? {
    guard text.hasPrefix(kCallLogPrefix) else { return nil }
    // Format: [[CALL_LOG]]:Missed | :Declined | :Ended:05:20
    let body = text.dropFirst(kCallLogPrefix.count + 1) // drop ":"
    let parts = body.split(separator: ":", maxSplits: 1).map(String.init)
    switch parts.first {
    case "Missed":   return .missed
    case "Declined": return .declined
    case "Ended":    return .ended(duration: parts.count > 1 ? parts[1] : "00:00")
    default:         return nil
    }
}

// MARK: - Call Info Card

private struct CallInfoCard: View {
    let kind: CallLogKind
    let isCurrentUser: Bool

    private var iconName: String {
        switch kind {
        case .missed, .declined: return "phone.down.fill"
        case .ended:             return "phone.fill"
        }
    }
    private var iconColor: Color {
        switch kind {
        case .missed, .declined: return .red
        case .ended:             return .green
        }
    }
    private var title: String {
        switch kind {
        case .missed:   return "Missed Call"
        case .declined: return "Call Declined"
        case .ended:    return "Audio Call"
        }
    }
    private var subtitle: String {
        switch kind {
        case .missed:              return "Tap to call back"
        case .declined:            return "Tap to call back"
        case .ended(let duration): return duration
        }
    }
    private var cardBackground: Color {
        isCurrentUser ? Color.accentColor.opacity(0.15) : Color(.systemGray5)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBackground)
        )
    }
}

// MARK: - MessageBubbleView

struct MessageBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        if let logKind = parseCallLog(message.text) {
            // ── Call info card — aligned like a text bubble ───────────────
            HStack(spacing: 8) {
                if isCurrentUser {
                    Spacer(minLength: 60)
                } else {
                    AvatarView(name: message.senderName)
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3) {
                    if !isCurrentUser {
                        Text(message.senderName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                    CallInfoCard(kind: logKind, isCurrentUser: isCurrentUser)
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

        } else {
            // ── Image bubble OR regular text bubble ───────────────────────
            HStack(alignment: .bottom, spacing: 8) {
                if isCurrentUser {
                    Spacer(minLength: 60)
                } else {
                    AvatarView(name: message.senderName)
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3) {
                    if !isCurrentUser {
                        Text(message.senderName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }

                    if let base64 = message.imageBase64,
                       let imageData = Data(base64Encoded: base64),
                       let uiImage = UIImage(data: imageData) {
                        // ── Image bubble ─────────────────────────────────
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 220)
                            .frame(minHeight: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color(.systemGray5), lineWidth: 0.5)
                            )
                    } else {
                        // ── Text bubble ──────────────────────────────────
                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(isCurrentUser ? .white : Color(.label))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                BubbleShape(isCurrentUser: isCurrentUser)
                                    .fill(isCurrentUser ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                    }

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
}

// MARK: - Previews

#Preview("Text bubble — outgoing") {
    let msg = ChatMessage(senderId: "me", senderName: "Me", text: "Hey there!")
    return MessageBubbleView(message: msg, isCurrentUser: true).padding()
}

#Preview("Call card — ended (outgoing)") {
    let msg = ChatMessage(senderId: "me", senderName: "Me",
                          text: "\(kCallLogPrefix):Ended:02:45")
    return MessageBubbleView(message: msg, isCurrentUser: true).padding()
}

#Preview("Call card — missed (incoming)") {
    let msg = ChatMessage(senderId: "alice", senderName: "Alice",
                          text: "\(kCallLogPrefix):Missed")
    return MessageBubbleView(message: msg, isCurrentUser: false).padding()
}
