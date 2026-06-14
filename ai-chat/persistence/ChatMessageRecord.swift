//
//  ChatMessageRecord.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation
import SwiftData

@Model
final class ChatMessageRecord {
    @Attribute(.unique) var id: UUID
    var content: String
    var roleRawValue: String
    var createdAt: Date
    var session: ChatSessionRecord?

    init(
        id: UUID = UUID(),
        content: String,
        role: ChatMessage.Role,
        createdAt: Date = .now,
        session: ChatSessionRecord? = nil
    ) {
        self.id = id
        self.content = content
        self.roleRawValue = role.rawValue
        self.createdAt = createdAt
        self.session = session
    }
}

extension ChatMessage {
    init(record: ChatMessageRecord) {
        self.init(
            id: record.id,
            content: record.content,
            role: ChatMessage.Role(rawValue: record.roleRawValue) ?? .assistant,
            createdAt: record.createdAt
        )
    }
}
