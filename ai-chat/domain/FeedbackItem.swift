//
//  FeedbackItem.swift
//  ai-chat
//
//  Created by Codex on 6/16/26.
//

import Foundation

enum FeedbackCorrectionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case grammar
    case betterToSay = "better_to_say"

    nonisolated var id: String {
        rawValue
    }

    nonisolated var title: String {
        switch self {
        case .grammar:
            "Grammar"
        case .betterToSay:
            "Better to Say"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .grammar:
            "Grammar, spelling, and word order"
        case .betterToSay:
            "Vocabulary, style, and natural phrasing"
        }
    }

    nonisolated var iconName: String {
        switch self {
        case .grammar:
            "textformat"
        case .betterToSay:
            "sparkles"
        }
    }

    nonisolated static func make(from rawValue: String?) -> FeedbackCorrectionCategory {
        guard let rawValue else { return .betterToSay }

        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "grammar", "spelling", "word_order", "wordorder":
            return .grammar
        case "better_to_say", "better", "vocabulary", "style", "other":
            return .betterToSay
        default:
            return .betterToSay
        }
    }
}

struct FeedbackItem: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let correction: MessageCorrection
    let sourceMessageID: ChatMessage.ID?
    let createdAt: Date

    nonisolated init(
        id: UUID = UUID(),
        correction: MessageCorrection,
        sourceMessageID: ChatMessage.ID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.correction = correction
        self.sourceMessageID = sourceMessageID
        self.createdAt = createdAt
    }

    nonisolated var category: FeedbackCorrectionCategory {
        FeedbackCorrectionCategory.make(from: correction.type)
    }
}
