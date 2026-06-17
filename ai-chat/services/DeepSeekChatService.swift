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
        let streamsStructuredResponses: Bool

        init(
            endpoint: URL,
            model: String,
            temperature: Double,
            timeoutInterval: TimeInterval = 60,
            streamsStructuredResponses: Bool = false
        ) {
            self.endpoint = endpoint
            self.model = model
            self.temperature = temperature
            self.timeoutInterval = timeoutInterval
            self.streamsStructuredResponses = streamsStructuredResponses
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
        let request = try makeURLRequest(
            from: messages,
            systemPrompt: systemPrompt,
            streamsResponse: false
        )

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

    nonisolated func responseEvents(
        for messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<ChatResponseEvent, Error> {
        let apiKey = apiKey
        let configuration = configuration
        let urlSession = urlSession

        guard configuration.streamsStructuredResponses else {
            return Self.completedResponseEvents(
                for: messages,
                systemPrompt: systemPrompt,
                apiKey: apiKey,
                configuration: configuration,
                urlSession: urlSession
            )
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.makeURLRequest(
                        from: messages,
                        systemPrompt: systemPrompt,
                        apiKey: apiKey,
                        configuration: configuration,
                        streamsResponse: true
                    )

                    let (bytes, response) = try await urlSession.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ChatServiceError.invalidResponse
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw ChatServiceError.httpFailure(statusCode: httpResponse.statusCode)
                    }

                    var streamParser = DeepSeekStreamingResponseParser()
                    for try await line in bytes.lines {
                        for event in try streamParser.events(fromServerSentEventLine: line) {
                            continuation.yield(event)
                        }
                    }

                    if let event = try streamParser.finishIfNeeded() {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    nonisolated private static func completedResponseEvents(
        for messages: [ChatMessage],
        systemPrompt: String,
        apiKey: String,
        configuration: Configuration,
        urlSession: URLSession
    ) -> AsyncThrowingStream<ChatResponseEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.makeURLRequest(
                        from: messages,
                        systemPrompt: systemPrompt,
                        apiKey: apiKey,
                        configuration: configuration,
                        streamsResponse: false
                    )
                    let response = try await Self.decodedResponse(from: request, urlSession: urlSession)
                    continuation.yield(.completed(response))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    nonisolated private func makeURLRequest(
        from messages: [ChatMessage],
        systemPrompt: String,
        streamsResponse: Bool
    ) throws -> URLRequest {
        try Self.makeURLRequest(
            from: messages,
            systemPrompt: systemPrompt,
            apiKey: apiKey,
            configuration: configuration,
            streamsResponse: streamsResponse
        )
    }

    nonisolated private static func makeURLRequest(
        from messages: [ChatMessage],
        systemPrompt: String,
        apiKey: String,
        configuration: Configuration,
        streamsResponse: Bool
    ) throws -> URLRequest {
        guard apiKey.isEmpty == false else {
            throw ChatServiceError.missingAPIKey
        }

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutInterval
        request.setValue(streamsResponse ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            Self.makeRequestBody(
                from: messages,
                systemPrompt: systemPrompt,
                configuration: configuration,
                streamsResponse: streamsResponse
            )
        )

        return request
    }

    nonisolated private static func makeRequestBody(
        from messages: [ChatMessage],
        systemPrompt: String,
        configuration: Configuration,
        streamsResponse: Bool
    ) -> ChatRequest {
        ChatRequest(
            model: configuration.model,
            messages: Self.requestContextMapper
                .requestMessages(from: messages, systemPrompt: systemPrompt)
                .map(ChatRequest.Message.init(contextMessage:)),
            temperature: configuration.temperature,
            responseFormat: .jsonObject,
            stream: streamsResponse ? true : nil
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
    let stream: Bool?

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
        case stream
    }

    nonisolated init(
        model: String,
        messages: [Message],
        temperature: Double,
        responseFormat: ResponseFormat? = nil,
        stream: Bool? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.responseFormat = responseFormat
        self.stream = stream
    }
}

nonisolated private struct ChatResponse: Decodable, Sendable {
    let choices: [Choice]

    nonisolated struct Choice: Decodable, Sendable {
        let message: ChatRequest.Message
    }
}

nonisolated struct DeepSeekStreamingResponseParser: Sendable {
    private var accumulatedContent = ""
    private var lastPartialReply = ""
    private var didComplete = false
    private let responseParser: AssistantResponseParser

    nonisolated init(responseParser: AssistantResponseParser = .standard) {
        self.responseParser = responseParser
    }

    mutating func events(fromServerSentEventLine line: String) throws -> [ChatResponseEvent] {
        guard didComplete == false else { return [] }

        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.hasPrefix("data:") else { return [] }

        let payload = trimmedLine
            .dropFirst("data:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard payload.isEmpty == false else { return [] }

        if payload == "[DONE]" {
            guard didComplete == false else { return [] }
            return [try completedEvent()]
        }

        guard let data = payload.data(using: .utf8),
              let response = try? JSONDecoder().decode(ChatStreamResponse.self, from: data)
        else {
            throw ChatServiceError.invalidResponse
        }

        let contentDelta = response.choices
            .compactMap { $0.delta?.content }
            .joined()

        guard contentDelta.isEmpty == false else { return [] }

        accumulatedContent += contentDelta

        guard let partialReply = responseParser.partialReply(from: accumulatedContent),
              partialReply != lastPartialReply
        else {
            return []
        }

        lastPartialReply = partialReply
        return [.partial(partialReply)]
    }

    mutating func finishIfNeeded() throws -> ChatResponseEvent? {
        guard didComplete == false else { return nil }
        return try completedEvent()
    }

    private mutating func completedEvent() throws -> ChatResponseEvent {
        guard didComplete == false else { throw ChatResponseStreamError.missingCompletedResponse }

        didComplete = true

        if let response = responseParser.structuredResponse(from: accumulatedContent),
           response.reply.isEmpty == false {
            return .completed(response)
        }

        if let response = responseParser.response(from: accumulatedContent),
           response.reply.isEmpty == false {
            return .completed(response)
        }

        throw ChatServiceError.emptyResponse
    }
}

nonisolated private struct ChatStreamResponse: Decodable, Sendable {
    let choices: [Choice]

    nonisolated struct Choice: Decodable, Sendable {
        let delta: Delta?

        nonisolated struct Delta: Decodable, Sendable {
            let content: String?
        }
    }
}

private extension String {
    nonisolated var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
