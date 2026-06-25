//
//  ChatServiceError.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

enum ChatServiceError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case httpFailure(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add DEEPSEEK_API_KEY in Secrets.plist before sending messages."
        case .invalidResponse:
            "The AI service returned an invalid response."
        case .emptyResponse:
            "The AI service returned an empty answer."
        case let .httpFailure(statusCode):
            "The AI service returned HTTP \(statusCode)."
        }
    }
}
