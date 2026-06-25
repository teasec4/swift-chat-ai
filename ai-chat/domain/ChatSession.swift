//
//  ChatSession.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation

struct ChatSession: Identifiable, Hashable, Sendable {
    nonisolated static let defaultTitle = "New Chat"

    let id: UUID
    var title: String
    var topicID: String?
    var topicTitle: String?
    var systemPrompt: String
    let createdAt: Date
    var updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        title: String = ChatSession.defaultTitle,
        topicID: String? = nil,
        topicTitle: String? = nil,
        systemPrompt: String = LanguageTopic.defaultSystemPrompt,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.topicID = topicID
        self.topicTitle = topicTitle
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    nonisolated static func title(fromFirstMessage content: String) -> String {
        let title = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 32 else { return title }

        let endIndex = title.index(title.startIndex, offsetBy: 32)
        return String(title[..<endIndex]) + "..."
    }
}
