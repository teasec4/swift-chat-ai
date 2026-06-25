//
//  MessageCorrection.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

struct MessageCorrection: Codable, Hashable, Sendable {
    let original: String
    let corrected: String
    let type: String?
    let explanation: String?

    init(
        original: String,
        corrected: String,
        type: String? = nil,
        explanation: String? = nil
    ) {
        self.original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        self.corrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type?.trimmedNonEmpty
        self.explanation = explanation?.trimmedNonEmpty
    }

    var isEmpty: Bool {
        original.isEmpty && corrected.isEmpty
    }

    func belongs(to learnerMessage: String) -> Bool {
        guard original.trimmedNonEmpty != nil else { return false }
        return learnerMessage.containsCorrectionPhrase(original)
    }

    private enum CodingKeys: String, CodingKey {
        case original
        case incorrect
        case mistake
        case corrected
        case correction
        case better
        case type
        case category
        case explanation
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            original: container.decodeFirstTrimmedString(for: [.original, .incorrect, .mistake]) ?? "",
            corrected: container.decodeFirstTrimmedString(for: [.corrected, .correction, .better]) ?? "",
            type: container.decodeFirstTrimmedString(for: [.type, .category]),
            explanation: container.decodeFirstTrimmedString(for: [.explanation, .note])
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(original, forKey: .original)
        try container.encode(corrected, forKey: .corrected)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(explanation, forKey: .explanation)
    }
}
