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
        message.content
    }
}

struct ChatContextPolicy: Hashable, Sendable {
    let maxMessages: Int
    let maxCharacters: Int

    nonisolated init(
        maxMessages: Int = 24,
        maxCharacters: Int = 8_000
    ) {
        self.maxMessages = max(1, maxMessages)
        self.maxCharacters = max(1, maxCharacters)
    }

    nonisolated func window(from messages: [ChatMessage]) -> [ChatMessage] {
        let contextMessages = messages.filter { $0.content.trimmedNonEmpty != nil }

        var selectedMessages: [ChatMessage] = []
        var selectedCharacterCount = 0

        for message in contextMessages.reversed() {
            let messageCharacterCount = message.content.trimmedNonEmpty?.count ?? 0
            let mustKeepLatestMessage = selectedMessages.isEmpty

            guard mustKeepLatestMessage || selectedMessages.count < maxMessages else {
                break
            }

            guard mustKeepLatestMessage || selectedCharacterCount + messageCharacterCount <= maxCharacters else {
                break
            }

            selectedMessages.append(message)
            selectedCharacterCount += messageCharacterCount
        }

        return selectedMessages.reversed()
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
