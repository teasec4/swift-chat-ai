//
//  DeepSeekChatService.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/11/26.
//

import Foundation

struct DeepSeekChatService: ChatServing {
    struct Configuration: Hashable, Sendable {
        let endpoint: URL
        let model: String
        let temperature: Double
        let timeoutInterval: TimeInterval

        init(
            endpoint: URL,
            model: String,
            temperature: Double,
            timeoutInterval: TimeInterval = 60
        ) {
            self.endpoint = endpoint
            self.model = model
            self.temperature = temperature
            self.timeoutInterval = timeoutInterval
        }

        nonisolated static let live = Configuration(
            endpoint: URL(string: "https://api.deepseek.com/v1/chat/completions")!,
            model: "deepseek-v4-flash",
            temperature: 0.7
        )
    }

    private let apiKey: String
    private let configuration: Configuration
    private let urlSession: URLSession

    nonisolated init(
        apiKey: String = Self.apiKeyFromBundle(),
        configuration: Configuration = .live,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.configuration = configuration
        self.urlSession = urlSession
    }

    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        let request = try makeURLRequest(from: messages, systemPrompt: systemPrompt)

        return try await Self.decodedResponse(from: request, urlSession: urlSession)
    }

    nonisolated private static func decodedResponse(
        from request: URLRequest,
        urlSession: URLSession
    ) async throws -> AssistantResponse {
        let (data, response) = try await urlSession.data(for: request)
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

    nonisolated private func makeURLRequest(
        from messages: [ChatMessage],
        systemPrompt: String
    ) throws -> URLRequest {
        try Self.makeURLRequest(
            from: messages,
            systemPrompt: systemPrompt,
            apiKey: apiKey,
            configuration: configuration
        )
    }

    nonisolated private static func makeURLRequest(
        from messages: [ChatMessage],
        systemPrompt: String,
        apiKey: String,
        configuration: Configuration
    ) throws -> URLRequest {
        guard apiKey.isEmpty == false else {
            throw ChatServiceError.missingAPIKey
        }

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            Self.makeRequestBody(
                from: messages,
                systemPrompt: systemPrompt,
                configuration: configuration
            )
        )

        return request
    }

    nonisolated private static func makeRequestBody(
        from messages: [ChatMessage],
        systemPrompt: String,
        configuration: Configuration
    ) -> ChatRequest {
        ChatRequest(
            model: configuration.model,
            messages: Self.requestContextMapper
                .requestMessages(from: messages, systemPrompt: systemPrompt)
                .map(ChatRequest.Message.init(contextMessage:)),
            temperature: configuration.temperature,
            responseFormat: .jsonObject
        )
    }

    nonisolated private static let requestContextMapper = ChatRequestContextMapper()
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

private extension DeepSeekChatService {
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
        let role: ChatRequestContextMessage.Role
        let content: String

        nonisolated init(contextMessage: ChatRequestContextMessage) {
            self.role = contextMessage.role
            self.content = contextMessage.content
        }
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
