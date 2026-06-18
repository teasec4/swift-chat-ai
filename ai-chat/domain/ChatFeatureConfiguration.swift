//
//  ChatFeatureConfiguration.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/15/26.
//

import Foundation

struct ChatFeatureConfiguration: Hashable, Sendable {
    let topics: [LanguageTopic]
    let rolePlayScenarios: [RolePlayScenario]
    let defaultSystemPrompt: String
    let openingRequest: String
    let maxContextMessages: Int
    let maxContextCharacters: Int

    init(
        topics: [LanguageTopic] = LanguageTopic.all,
        rolePlayScenarios: [RolePlayScenario] = RolePlayScenario.all,
        defaultSystemPrompt: String = LanguageTopic.defaultSystemPrompt,
        openingRequest: String = LanguageTopic.openingRequest,
        maxContextMessages: Int = 24,
        maxContextCharacters: Int = 8_000
    ) {
        self.topics = topics
        self.rolePlayScenarios = rolePlayScenarios
        self.defaultSystemPrompt = defaultSystemPrompt
        self.openingRequest = openingRequest
        self.maxContextMessages = max(1, maxContextMessages)
        self.maxContextCharacters = max(1, maxContextCharacters)
    }

    nonisolated static let englishPractice = ChatFeatureConfiguration()

    nonisolated var contextPolicy: ChatContextPolicy {
        ChatContextPolicy(
            maxMessages: maxContextMessages,
            maxCharacters: maxContextCharacters
        )
    }

    func topic(for session: ChatSession?) -> LanguageTopic? {
        guard let topicID = session?.topicID else { return nil }
        return topics.first { $0.id == topicID }
    }

    func rolePlayScenario(for session: ChatSession?) -> RolePlayScenario? {
        guard let topicID = session?.topicID else { return nil }
        return rolePlayScenarios.first { $0.sessionTopicID == topicID }
    }
}
