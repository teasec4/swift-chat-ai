//
//  ChatSessionDraft.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/15/26.
//

import Foundation

struct ChatSessionDraft: Hashable, Sendable {
    let title: String
    let topicID: String?
    let topicTitle: String?
    let systemPrompt: String

    init(
        title: String = ChatSession.defaultTitle,
        topicID: String? = nil,
        topicTitle: String? = nil,
        systemPrompt: String
    ) {
        self.title = title
        self.topicID = topicID
        self.topicTitle = topicTitle
        self.systemPrompt = systemPrompt
    }

    init(topic: LanguageTopic?, defaultSystemPrompt: String) {
        self.init(
            title: topic?.title ?? ChatSession.defaultTitle,
            topicID: topic?.id,
            topicTitle: topic?.title,
            systemPrompt: topic?.systemPrompt ?? defaultSystemPrompt
        )
    }
}
