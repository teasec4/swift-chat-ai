//
//  AssistantResponse.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/14/26.
//

import Foundation

struct AssistantResponse: Codable, Hashable, Sendable {
    let reply: String
    let corrections: [MessageCorrection]

    nonisolated init(
        reply: String,
        corrections: [MessageCorrection] = []
    ) {
        self.reply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        self.corrections = corrections.filter { $0.isEmpty == false }
    }

    nonisolated static let responseInstructions = """
    Return only one valid JSON object. Do not wrap it in Markdown.
    The JSON object must always include a non-empty "reply" string.
    Never return {}, null, an empty string, or a JSON object with an empty reply.
    Previous assistant messages may appear as plain conversation text. Still return the next assistant response as this JSON object.

    JSON schema:
    {
      "reply": "A short, friendly teacher response that continues the conversation and asks one clear question.",
      "corrections": [
        {
          "original": "The learner phrase with the mistake.",
          "corrected": "A natural corrected version.",
          "type": "grammar | better_to_say",
          "explanation": "One short explanation."
        }
      ]
    }

    Use "grammar" for grammar, spelling, and word-order issues.
    Use "better_to_say" for vocabulary, style, clarity, and more natural phrasing.
    Corrections must refer only to the learner's most recent user message. Do not include corrections for earlier messages.
    The "original" value must be an exact phrase from the learner's most recent user message.
    If the learner made no important mistakes, return an empty corrections array.
    If you are unsure what to say, ask one simple follow-up question in "reply" and return an empty corrections array.
    """

    private enum CodingKeys: String, CodingKey {
        case reply
        case message
        case response
        case answer
        case corrections
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reply = container.decodeFirstTrimmedString(for: [.reply, .message, .response, .answer]) ?? ""
        let corrections = (try? container.decodeIfPresent([MessageCorrection].self, forKey: .corrections)) ?? []

        self.init(reply: reply, corrections: corrections)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reply, forKey: .reply)
        try container.encode(corrections, forKey: .corrections)
    }

    nonisolated func keepingCorrections(for learnerMessage: String?) -> AssistantResponse {
        guard let learnerMessage,
              learnerMessage.trimmedNonEmpty != nil
        else {
            return AssistantResponse(reply: reply)
        }

        return AssistantResponse(
            reply: reply,
            corrections: corrections.filter { $0.belongs(to: learnerMessage) }
        )
    }
}


