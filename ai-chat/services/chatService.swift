//
//  chatService.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/11/26.
//

import Foundation

protocol ChatServing: Sendable {
    nonisolated func response(for messages: [ChatMessage]) async throws -> String
}

struct ChatService: ChatServing {
    private let apiKey = ""
    private let model = "gpt-4.1-mini"
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let systemPrompt = "You are a helpful assistant."
    private let temperature = 0.7

    nonisolated init() {}

    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        guard apiKey.isEmpty == false else {
            throw ChatServiceError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(makeRequestBody(from: messages))

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

        return content
    }

    nonisolated private func makeRequestBody(from messages: [ChatMessage]) -> ChatRequest {
        ChatRequest(
            model: model,
            messages: [
                ChatRequest.Message(role: "system", content: systemPrompt)
            ] + messages.map {
                ChatRequest.Message(role: $0.role.rawValue, content: $0.content)
            },
            temperature: temperature
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
            "Add an API key in ChatService.swift before sending messages."
        case .invalidResponse:
            "The AI service returned an invalid response."
        case .emptyResponse:
            "The AI service returned an empty answer."
        case let .httpFailure(statusCode):
            "The AI service returned HTTP \(statusCode)."
        }
    }
}

nonisolated private struct ChatRequest: Encodable, Sendable {
    let model: String
    let messages: [Message]
    let temperature: Double

    nonisolated struct Message: Codable, Sendable {
        let role: String
        let content: String
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
