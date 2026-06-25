//
//  ChatRequestContextMapper.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

struct ChatRequestContextMapper: Sendable {
    func requestMessages(
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

    func conversationMessages(from messages: [ChatMessage]) -> [ChatRequestContextMessage] {
        messages.compactMap { message in
            guard let content = content(for: message).trimmedNonEmpty else { return nil }

            return ChatRequestContextMessage(
                role: ChatRequestContextMessage.Role(messageRole: message.role),
                content: content
            )
        }
    }

    private func content(for message: ChatMessage) -> String {
        message.content
    }
}

private extension ChatRequestContextMessage.Role {
    init(messageRole: ChatMessage.Role) {
        switch messageRole {
        case .user:
            self = .user
        case .assistant:
            self = .assistant
        }
    }
}
