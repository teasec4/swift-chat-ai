//
//  chatMessage.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/11/26.
//

import Foundation

struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let content: String
    let role: Role
    let createdAt: Date

    nonisolated init(
        id: UUID = UUID(),
        content: String,
        role: Role,
        createdAt: Date = .now
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.createdAt = createdAt
    }

    enum Role: String, Hashable, Sendable {
        case user
        case assistant
    }
}

extension ChatMessage {
    nonisolated static let previewMessages: [ChatMessage] = [
        ChatMessage(content: "Hello", role: .user),
        ChatMessage(content: "Hi! What are we building today?", role: .assistant),
        ChatMessage(content: "Let's make this chat feel nicer.", role: .user),
        ChatMessage(content: "Good plan. I can help with that.", role: .assistant)
    ]
}
