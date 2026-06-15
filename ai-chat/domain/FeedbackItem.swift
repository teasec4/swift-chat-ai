//
//  FeedbackItem.swift
//  ai-chat
//
//  Created by Codex on 6/16/26.
//

import Foundation

enum FeedbackCorrectionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case grammar
    case vocabulary
    case wordOrder = "word_order"
    case spelling
    case style
    case other

    nonisolated var id: String {
        rawValue
    }

    nonisolated var title: String {
        switch self {
        case .grammar:
            "Grammar"
        case .vocabulary:
            "Vocabulary"
        case .wordOrder:
            "Word Order"
        case .spelling:
            "Spelling"
        case .style:
            "Style"
        case .other:
            "Other"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .grammar:
            "Tenses, articles, agreement"
        case .vocabulary:
            "Word choice and natural phrasing"
        case .wordOrder:
            "Sentence structure and order"
        case .spelling:
            "Typos and written accuracy"
        case .style:
            "Tone, clarity, and fluency"
        case .other:
            "Useful notes that do not fit elsewhere"
        }
    }

    nonisolated var iconName: String {
        switch self {
        case .grammar:
            "textformat"
        case .vocabulary:
            "character.book.closed"
        case .wordOrder:
            "arrow.left.arrow.right"
        case .spelling:
            "checkmark.seal"
        case .style:
            "sparkles"
        case .other:
            "ellipsis.circle"
        }
    }

    nonisolated static func make(from rawValue: String?) -> FeedbackCorrectionCategory {
        guard let rawValue else { return .other }

        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        return FeedbackCorrectionCategory(rawValue: normalized) ?? .other
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
