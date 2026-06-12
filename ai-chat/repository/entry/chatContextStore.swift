//
//  chatContextStore.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/12/26.
//

import Foundation

struct ChatContextStore: Sendable {
    private(set) var messages: [ChatMessage]
    let maxMessages: Int

    nonisolated init(messages: [ChatMessage] = [], maxMessages: Int = 12) {
        self.maxMessages = Swift.max(1, maxMessages)
        self.messages = Array(messages.suffix(self.maxMessages))
    }

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        trimToLimit()
    }

    mutating func remove(id: UUID) {
        messages.removeAll { $0.id == id }
    }

    private mutating func trimToLimit() {
        guard messages.count > maxMessages else { return }
        messages = Array(messages.suffix(maxMessages))
    }
}
