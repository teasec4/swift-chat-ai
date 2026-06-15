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

    init(
        topics: [LanguageTopic] = LanguageTopic.all,
        rolePlayScenarios: [RolePlayScenario] = RolePlayScenario.all,
        defaultSystemPrompt: String = LanguageTopic.defaultSystemPrompt,
        openingRequest: String = LanguageTopic.openingRequest,
        maxContextMessages: Int = 24
    ) {
        self.topics = topics
        self.rolePlayScenarios = rolePlayScenarios
        self.defaultSystemPrompt = defaultSystemPrompt
        self.openingRequest = openingRequest
        self.maxContextMessages = max(1, maxContextMessages)
    }

    nonisolated static let englishPractice = ChatFeatureConfiguration()

    func topic(for session: ChatSession?) -> LanguageTopic? {
        guard let topicID = session?.topicID else { return nil }
        return topics.first { $0.id == topicID }
    }

    func rolePlayScenario(for session: ChatSession?) -> RolePlayScenario? {
        guard let topicID = session?.topicID else { return nil }
        return rolePlayScenarios.first { $0.sessionTopicID == topicID }
    }
}
