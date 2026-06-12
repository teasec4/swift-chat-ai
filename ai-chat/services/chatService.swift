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

struct ChatServiceConfiguration: Sendable, Equatable {
    let baseURL: URL
    let apiKey: String?
    let model: String
    let systemPrompt: String?
    let temperature: Double
    let requiresAPIKey: Bool

    nonisolated init(
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        apiKey: String? = nil,
        model: String = "gpt-4.1-mini",
        systemPrompt: String? = "You are a helpful assistant.",
        temperature: Double = 0.7,
        requiresAPIKey: Bool = true
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey?.nilIfBlank
        self.model = model
        self.systemPrompt = systemPrompt?.nilIfBlank
        self.temperature = temperature
        self.requiresAPIKey = requiresAPIKey
    }
}

struct OpenAICompatibleChatService: ChatServing {
    let configuration: ChatServiceConfiguration

    nonisolated init(configuration: ChatServiceConfiguration = ChatServiceConfiguration()) {
        self.configuration = configuration
    }

    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        if configuration.requiresAPIKey && configuration.apiKey == nil {
            throw ChatServiceError.missingAPIKey
        }

        var request = URLRequest(url: configuration.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = ChatCompletionRequest(
            model: configuration.model,
            messages: requestMessages(from: messages),
            temperature: configuration.temperature
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ChatServiceError.httpFailure(
                statusCode: httpResponse.statusCode,
                message: Self.errorMessage(from: data)
            )
        }

        let decodedResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decodedResponse.choices.first?.message.content.nilIfBlank else {
            throw ChatServiceError.emptyResponse
        }

        return content
    }

    private func requestMessages(from messages: [ChatMessage]) -> [ChatCompletionMessage] {
        var requestMessages: [ChatCompletionMessage] = []

        if let systemPrompt = configuration.systemPrompt {
            requestMessages.append(ChatCompletionMessage(role: "system", content: systemPrompt))
        }

        requestMessages.append(contentsOf: messages.map {
            ChatCompletionMessage(role: $0.role.rawValue, content: $0.content)
        })

        return requestMessages
    }
}

enum ChatServiceError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case httpFailure(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Missing API key. Provide apiKey in ChatServiceConfiguration before sending messages."
        case .invalidResponse:
            "The AI service returned an invalid response."
        case .emptyResponse:
            "The AI service returned an empty answer."
        case let .httpFailure(statusCode, message):
            if let message {
                "The AI service returned \(statusCode): \(message)"
            } else {
                "The AI service returned HTTP \(statusCode)."
            }
        }
    }
}

private struct ChatCompletionRequest: Encodable, Sendable {
    let model: String
    let messages: [ChatCompletionMessage]
    let temperature: Double
}

private struct ChatCompletionMessage: Codable, Sendable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable, Sendable {
    let choices: [Choice]

    struct Choice: Decodable, Sendable {
        let message: ChatCompletionMessage
    }
}

private struct ChatCompletionErrorResponse: Decodable {
    let error: APIError?

    struct APIError: Decodable {
        let message: String?
    }
}

private extension ChatServiceConfiguration {
    nonisolated var chatCompletionsURL: URL {
        baseURL.appending(path: "chat/completions")
    }
}

private extension OpenAICompatibleChatService {
    nonisolated static func errorMessage(from data: Data) -> String? {
        if let response = try? JSONDecoder().decode(ChatCompletionErrorResponse.self, from: data) {
            return response.error?.message?.nilIfBlank
        }

        return String(data: data, encoding: .utf8)?.nilIfBlank
    }
}

private extension String {
    nonisolated var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
