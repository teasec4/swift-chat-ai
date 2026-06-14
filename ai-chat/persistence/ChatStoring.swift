//
//  ChatStoring.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation

@MainActor
protocol ChatStoring: AnyObject {
    func fetchSessions() throws -> [ChatSession]
    func createSession(topic: LanguageTopic?) throws -> ChatSession
    func fetchMessages(for sessionID: UUID) throws -> [ChatMessage]
    func appendMessage(_ message: ChatMessage, to sessionID: UUID) throws
    func deleteSession(id: UUID) throws
}

enum ChatStoreError: LocalizedError {
    case sessionNotFound

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            "Chat session was not found."
        }
    }
}
