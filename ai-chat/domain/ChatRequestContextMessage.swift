//
//  ChatRequestContextMessage.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

struct ChatRequestContextMessage: Codable, Hashable, Sendable {
    let role: Role
    let content: String

    init(role: Role, content: String) {
        self.role = role
        self.content = content
    }

    enum Role: String, Codable, Hashable, Sendable {
        case system
        case user
        case assistant
    }
}
