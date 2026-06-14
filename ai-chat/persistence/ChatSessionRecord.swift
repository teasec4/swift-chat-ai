//
//  ChatSessionRecord.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation
import SwiftData

@Model
final class ChatSessionRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var topicID: String?
    var topicTitle: String?
    var systemPrompt: String = LanguageTopic.defaultSystemPrompt
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
    var messages: [ChatMessageRecord]

    init(
        id: UUID = UUID(),
        title: String = ChatSession.defaultTitle,
        topicID: String? = nil,
        topicTitle: String? = nil,
        systemPrompt: String = LanguageTopic.defaultSystemPrompt,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        messages: [ChatMessageRecord] = []
    ) {
        self.id = id
        self.title = title
        self.topicID = topicID
        self.topicTitle = topicTitle
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

extension ChatSession {
    init(record: ChatSessionRecord) {
        self.init(
            id: record.id,
            title: record.title,
            topicID: record.topicID,
            topicTitle: record.topicTitle,
            systemPrompt: record.systemPrompt,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}
