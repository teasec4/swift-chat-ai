//
//  ChatServing.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/14/26.
//

protocol ChatServing: Sendable {
    nonisolated func response(
        for messages: [ChatMessage],
        systemPrompt: String
    ) async throws -> AssistantResponse

    nonisolated func responseEvents(
        for messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<ChatResponseEvent, Error>
}

extension ChatServing {
    nonisolated func responseEvents(
        for messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<ChatResponseEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let response = try await response(for: messages, systemPrompt: systemPrompt)
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
}
