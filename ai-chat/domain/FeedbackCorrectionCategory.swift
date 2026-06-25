//
//  FeedbackCorrectionCategory.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

enum FeedbackCorrectionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case grammar
    case betterToSay = "better_to_say"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .grammar:
            "Grammar"
        case .betterToSay:
            "Better to Say"
        }
    }

    var subtitle: String {
        switch self {
        case .grammar:
            "Grammar, spelling, and word order"
        case .betterToSay:
            "Vocabulary, style, and natural phrasing"
        }
    }

    var iconName: String {
        switch self {
        case .grammar:
            "textformat"
        case .betterToSay:
            "sparkles"
        }
    }

    static func make(from rawValue: String?) -> FeedbackCorrectionCategory {
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
