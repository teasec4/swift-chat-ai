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
    var correctionsData: Data?
    var session: ChatSessionRecord?

    init(
        id: UUID = UUID(),
        content: String,
        role: ChatMessage.Role,
        createdAt: Date = .now,
        corrections: [MessageCorrection] = [],
        session: ChatSessionRecord? = nil
    ) {
        self.id = id
        self.content = content
        self.roleRawValue = role.rawValue
        self.createdAt = createdAt
        self.correctionsData = Self.encodeCorrections(corrections)
        self.session = session
    }
}

extension ChatMessage {
    init(record: ChatMessageRecord) {
        self.init(
            id: record.id,
            content: record.content,
            role: ChatMessage.Role(rawValue: record.roleRawValue) ?? .assistant,
            createdAt: record.createdAt,
            corrections: ChatMessageRecord.decodeCorrections(from: record.correctionsData)
        )
    }
}

private extension ChatMessageRecord {
    static func encodeCorrections(_ corrections: [MessageCorrection]) -> Data? {
        guard corrections.isEmpty == false else { return nil }
        return try? JSONEncoder().encode(corrections)
    }

    static func decodeCorrections(from data: Data?) -> [MessageCorrection] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([MessageCorrection].self, from: data)) ?? []
    }
}
