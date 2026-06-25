//
//  FeedbackItem.swift
//  ai-chat
//
//  Created by Codex on 6/16/26.
//

import Foundation

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
