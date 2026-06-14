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

struct LanguageTopic: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let systemPrompt: String

    nonisolated init(
        id: String,
        title: String,
        subtitle: String,
        iconName: String,
        systemPrompt: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.systemPrompt = systemPrompt
    }

    nonisolated static let defaultSystemPrompt = makeSystemPrompt(
        topicTitle: "Everyday conversation",
        topicDescription: "friendly everyday situations"
    )

    nonisolated static let openingRequest = """
    Start this practice conversation now. Write one short, friendly greeting and ask exactly one clear question about the topic. Do not explain the rules yet.
    """

    nonisolated static let all: [LanguageTopic] = [
        LanguageTopic(
            id: "daily-life",
            title: "Daily Life",
            subtitle: "Small talk, routines, plans",
            iconName: "sun.max",
            systemPrompt: makeSystemPrompt(
                topicTitle: "Daily Life",
                topicDescription: "daily routines, weekend plans, habits, small talk, and simple personal stories"
            )
        ),
        LanguageTopic(
            id: "travel",
            title: "Travel",
            subtitle: "Trips, hotels, airports",
            iconName: "airplane",
            systemPrompt: makeSystemPrompt(
                topicTitle: "Travel",
                topicDescription: "trips, airports, hotels, directions, restaurants, and travel problems"
            )
        ),
        LanguageTopic(
            id: "food",
            title: "Food",
            subtitle: "Restaurants and recipes",
            iconName: "fork.knife",
            systemPrompt: makeSystemPrompt(
                topicTitle: "Food",
                topicDescription: "restaurants, cooking, recipes, favorite dishes, groceries, and ordering food"
            )
        ),
        LanguageTopic(
            id: "work",
            title: "Work",
            subtitle: "Meetings and colleagues",
            iconName: "briefcase",
            systemPrompt: makeSystemPrompt(
                topicTitle: "Work",
                topicDescription: "meetings, projects, colleagues, emails, interviews, and work routines"
            )
        ),
        LanguageTopic(
            id: "hobbies",
            title: "Hobbies",
            subtitle: "Free time and interests",
            iconName: "gamecontroller",
            systemPrompt: makeSystemPrompt(
                topicTitle: "Hobbies",
                topicDescription: "free time, sports, games, books, music, movies, and personal interests"
            )
        ),
        LanguageTopic(
            id: "interview",
            title: "Interview",
            subtitle: "Practice confident answers",
            iconName: "person.text.rectangle",
            systemPrompt: makeSystemPrompt(
                topicTitle: "Interview",
                topicDescription: "job interviews, self-presentation, experience, strengths, weaknesses, and follow-up questions"
            )
        )
    ]

    nonisolated private static func makeSystemPrompt(
        topicTitle: String,
        topicDescription: String
    ) -> String {
        """
        You are a friendly foreign-language teacher. The learner is practicing conversational English unless they explicitly ask for another language.

        Conversation topic: \(topicTitle).
        Topic scope: \(topicDescription).

        Your job:
        - Keep the conversation warm, natural, and friendly.
        - Ask one clear question at a time.
        - Encourage the learner to answer with full sentences.
        - Correct important grammar, vocabulary, and word-order mistakes gently.
        - When correcting, show a short correction and a better version, then continue the conversation.
        - Do not overload the learner with long explanations.
        - If the learner writes in Russian, you may briefly explain the correction in Russian, then return to the target-language practice.
        """
    }
}
