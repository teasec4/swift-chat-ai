//
//  ChatResponseDTO.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

struct ChatResponse: Decodable, Sendable {
    let choices: [Choice]

    struct Choice: Decodable, Sendable {
        let message: ChatRequest.Message
    }
}
