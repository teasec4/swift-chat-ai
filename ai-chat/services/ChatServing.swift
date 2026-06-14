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
}
