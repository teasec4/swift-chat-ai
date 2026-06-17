//
//  ChatRequestContext.swift
//  ai-chat
//
//  Created by Codex on 6/17/26.
//

import Foundation

struct ChatRequestContextMessage: Codable, Hashable, Sendable {
    let role: Role
    let content: String

    nonisolated init(role: Role, content: String) {
        self.role = role
        self.content = content
    }

    enum Role: String, Codable, Hashable, Sendable {
        case system
        case user
        case assistant
    }
}

struct ChatRequestContextMapper: Sendable {
    let assistantHistoryEncoding: AssistantHistoryEncoding

    nonisolated init(assistantHistoryEncoding: AssistantHistoryEncoding = .structuredResponseJSON) {
        self.assistantHistoryEncoding = assistantHistoryEncoding
    }

    nonisolated func requestMessages(
        from messages: [ChatMessage],
        systemPrompt: String,
        responseInstructions: String = AssistantResponse.responseInstructions
    ) -> [ChatRequestContextMessage] {
        [
            ChatRequestContextMessage(role: .system, content: systemPrompt),
            ChatRequestContextMessage(role: .system, content: responseInstructions)
        ]
        .filter { $0.content.trimmedNonEmpty != nil } + conversationMessages(from: messages)
    }

    nonisolated func conversationMessages(from messages: [ChatMessage]) -> [ChatRequestContextMessage] {
        messages.compactMap { message in
            guard let content = content(for: message).trimmedNonEmpty else { return nil }

            return ChatRequestContextMessage(
                role: ChatRequestContextMessage.Role(messageRole: message.role),
                content: content
            )
        }
    }

    private nonisolated func content(for message: ChatMessage) -> String {
        switch (message.role, assistantHistoryEncoding) {
        case (.assistant, .structuredResponseJSON):
            encodedAssistantResponse(from: message) ?? message.content
        default:
            message.content
        }
    }

    private nonisolated func encodedAssistantResponse(from message: ChatMessage) -> String? {
        guard message.content.trimmedNonEmpty != nil else { return nil }

        let response = AssistantResponse(reply: message.content, corrections: message.corrections)
        guard let data = try? JSONEncoder().encode(response) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum AssistantHistoryEncoding: Hashable, Sendable {
        case plainText
        case structuredResponseJSON
    }
}

private extension ChatRequestContextMessage.Role {
    nonisolated init(messageRole: ChatMessage.Role) {
        switch messageRole {
        case .user:
            self = .user
        case .assistant:
            self = .assistant
        }
    }
}

private extension String {
    nonisolated var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
