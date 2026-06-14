//
//  ChatService.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/11/26.
//

import Foundation

struct ChatService: ChatServing {
    private let apiKey: String
    private let model = "deepseek-v4-flash"
    private let endpoint = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    private let temperature = 0.7

    nonisolated init(apiKey: String = Self.apiKeyFromBundle()) {
        self.apiKey = apiKey
    }

    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        guard apiKey.isEmpty == false else {
            throw ChatServiceError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            makeRequestBody(from: messages, systemPrompt: systemPrompt)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ChatServiceError.httpFailure(statusCode: httpResponse.statusCode)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content.trimmedNonEmpty else {
            throw ChatServiceError.emptyResponse
        }

        guard let response = AssistantResponse.make(from: content) else {
            throw ChatServiceError.emptyResponse
        }

        return response
    }

    nonisolated private func makeRequestBody(
        from messages: [ChatMessage],
        systemPrompt: String
    ) -> ChatRequest {
        ChatRequest(
            model: model,
            messages: [
                ChatRequest.Message(role: "system", content: systemPrompt),
                ChatRequest.Message(role: "system", content: AssistantResponse.responseInstructions)
            ] + messages.map {
                ChatRequest.Message(role: $0.role.rawValue, content: $0.content)
            },
            temperature: temperature,
            responseFormat: .jsonObject
        )
    }
}

enum ChatServiceError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case httpFailure(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add DEEPSEEK_API_KEY in Secrets.plist before sending messages."
        case .invalidResponse:
            "The AI service returned an invalid response."
        case .emptyResponse:
            "The AI service returned an empty answer."
        case let .httpFailure(statusCode):
            "The AI service returned HTTP \(statusCode)."
        }
    }
}

private extension ChatService {
    nonisolated static func apiKeyFromBundle() -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String,
           let apiKey = normalizedAPIKey(value) {
            return apiKey
        }

        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let value = plist["DEEPSEEK_API_KEY"] as? String,
            let apiKey = normalizedAPIKey(value)
        else {
            return ""
        }

        return apiKey
    }

    nonisolated static func normalizedAPIKey(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.contains("$(") == false else {
            return nil
        }

        return trimmed
    }
}

nonisolated private struct ChatRequest: Encodable, Sendable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat?

    nonisolated struct Message: Codable, Sendable {
        let role: String
        let content: String
    }

    nonisolated struct ResponseFormat: Codable, Sendable {
        let type: String

        nonisolated static let jsonObject = ResponseFormat(type: "json_object")
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }

    nonisolated init(
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

nonisolated private struct ChatResponse: Decodable, Sendable {
    let choices: [Choice]

    nonisolated struct Choice: Decodable, Sendable {
        let message: ChatRequest.Message
    }
}

private extension String {
    nonisolated var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
