//
//  ChatErrorNotice.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/15/26.
//

import Foundation

struct ChatErrorNotice: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String
    let canRetry: Bool

    init(
        id: UUID = UUID(),
        message: String,
        canRetry: Bool
    ) {
        self.id = id
        self.message = message
        self.canRetry = canRetry
    }
}
