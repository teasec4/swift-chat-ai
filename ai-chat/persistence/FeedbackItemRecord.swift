//
//  FeedbackItemRecord.swift
//  ai-chat
//
//  Created by Codex on 6/17/26.
//

import Foundation
import SwiftData

@Model
final class FeedbackItemRecord {
    @Attribute(.unique) var id: UUID
    var original: String
    var corrected: String
    var type: String?
    var explanation: String?
    var sourceMessageID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        correction: MessageCorrection,
        sourceMessageID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.original = correction.original
        self.corrected = correction.corrected
        self.type = correction.type
        self.explanation = correction.explanation
        self.sourceMessageID = sourceMessageID
        self.createdAt = createdAt
    }

    func update(from item: FeedbackItem) {
        original = item.correction.original
        corrected = item.correction.corrected
        type = item.correction.type
        explanation = item.correction.explanation
        sourceMessageID = item.sourceMessageID
        createdAt = item.createdAt
    }
}

extension FeedbackItem {
    init(record: FeedbackItemRecord) {
        self.init(
            id: record.id,
            correction: MessageCorrection(
                original: record.original,
                corrected: record.corrected,
                type: record.type,
                explanation: record.explanation
            ),
            sourceMessageID: record.sourceMessageID,
            createdAt: record.createdAt
        )
    }
}
