//
//  ChatResponseEvent.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/15/26.
//

import Foundation

enum ChatResponseEvent: Equatable, Sendable {
    case partial(String)
    case completed(AssistantResponse)
}

enum ChatResponseStreamError: LocalizedError, Equatable {
    case missingCompletedResponse

    var errorDescription: String? {
        switch self {
        case .missingCompletedResponse:
            "The AI service finished without a complete answer."
        }
    }
}
