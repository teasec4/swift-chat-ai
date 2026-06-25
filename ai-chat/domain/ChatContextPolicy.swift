//
//  ChatContextPolicy.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

struct ChatContextPolicy: Hashable, Sendable {
    let maxMessages: Int
    let maxCharacters: Int

    init(
        maxMessages: Int = 24,
        maxCharacters: Int = 8_000
    ) {
        self.maxMessages = max(1, maxMessages)
        self.maxCharacters = max(1, maxCharacters)
    }

    func window(from messages: [ChatMessage]) -> [ChatMessage] {
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
