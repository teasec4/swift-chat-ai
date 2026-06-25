//
//  ChatRequestDTO.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

struct ChatRequest: Encodable, Sendable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat?

    struct Message: Codable, Sendable {
        let role: ChatRequestContextMessage.Role
        let content: String

        init(contextMessage: ChatRequestContextMessage) {
            self.role = contextMessage.role
            self.content = contextMessage.content
        }
    }

    struct ResponseFormat: Codable, Sendable {
        let type: String

        static let jsonObject = ResponseFormat(type: "json_object")
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }

    init(
        model: String,
        messages: [Message],
        temperature: Double,
        responseFormat: ResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.responseFormat = responseFormat
    }
}
