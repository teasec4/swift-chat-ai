//
//  RolePlayScenario.swift
//  ai-chat
//
//  Created by Codex on 6/15/26.
//

import Foundation

struct RolePlayScenario: Identifiable, Hashable, Sendable {
    nonisolated private static let sessionTopicIDPrefix = "role-play."

    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let assistantRole: String
    let learnerRole: String
    let situation: String

    nonisolated init(
        id: String,
        title: String,
        subtitle: String,
        iconName: String,
        assistantRole: String,
        learnerRole: String,
        situation: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.assistantRole = assistantRole
        self.learnerRole = learnerRole
        self.situation = situation
    }

    nonisolated var sessionTopicID: String {
        Self.sessionTopicIDPrefix + id
    }

    nonisolated static let genericOpeningRequest = """
    Start this role play now. Stay in character, set the scene in one short sentence, and ask exactly one natural first question. Do not explain the rules.
    """

    nonisolated static func isRolePlayTopicID(_ topicID: String) -> Bool {
        topicID.hasPrefix(sessionTopicIDPrefix)
    }

    nonisolated var openingRequest: String {
        """
        Start this role play now. Stay in character as \(assistantRole), set the scene in one short sentence, and ask exactly one natural first question. Do not explain the rules.
        """
    }

    nonisolated var systemPrompt: String {
        """
        You are a friendly English role-play partner and language coach.

        Role-play scenario: \(title).
        Situation: \(situation).
        You play: \(assistantRole).
        The learner plays: \(learnerRole).

        Your job:
        - Stay in character and keep the scene realistic.
        - Ask one clear question or give one clear prompt at a time.
        - Keep replies short enough for speaking practice.
        - Gently correct important grammar, vocabulary, and word-order mistakes.
        - Continue the role play after corrections instead of turning it into a lesson.
        - If the learner writes in Russian, briefly clarify in Russian, then return to English practice.
        - Do not ask for real private identifiers, passport numbers, payment card numbers, or other sensitive data.
        """
    }

    nonisolated static func custom(
        scenario: String,
        assistantRole: String,
        learnerRole: String,
        additionalDetail: String?
    ) -> RolePlayScenario {
        let trimmedScenario = sanitized(scenario)
        let trimmedAssistantRole = sanitized(assistantRole)
        let trimmedLearnerRole = sanitized(learnerRole)
        let trimmedAdditionalDetail = sanitized(additionalDetail ?? "")
        let situation: String

        if trimmedAdditionalDetail.isEmpty {
            situation = trimmedScenario
        } else {
            situation = "\(trimmedScenario)\nAdditional detail: \(trimmedAdditionalDetail)"
        }

        return RolePlayScenario(
            id: "custom.\(UUID().uuidString.lowercased())",
            title: trimmedScenario,
            subtitle: "Custom scenario",
            iconName: "wand.and.sparkles",
            assistantRole: trimmedAssistantRole,
            learnerRole: trimmedLearnerRole,
            situation: situation
        )
    }

    nonisolated static let all: [RolePlayScenario] = [
        RolePlayScenario(
            id: "job-interview",
            title: "Job Interview",
            subtitle: "Answer questions with confidence",
            iconName: "person.text.rectangle",
            assistantRole: "a calm hiring manager",
            learnerRole: "a candidate interviewing for a new job",
            situation: "A first-round job interview where the learner practices introducing experience, strengths, and motivation."
        ),
        RolePlayScenario(
            id: "store",
            title: "In a Store",
            subtitle: "Ask for help and buy items",
            iconName: "cart",
            assistantRole: "a helpful store assistant",
            learnerRole: "a customer looking for an item and asking questions",
            situation: "A simple store conversation about finding an item, asking about size or price, and paying."
        ),
        RolePlayScenario(
            id: "border-control",
            title: "Border Control",
            subtitle: "Practice routine travel questions",
            iconName: "globe",
            assistantRole: "a polite border officer",
            learnerRole: "a traveler entering another country",
            situation: "A routine border-control conversation about trip purpose, stay length, accommodation, and return plans."
        )
    ]

    nonisolated private static func sanitized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
