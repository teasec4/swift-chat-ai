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
    func createSession(from draft: ChatSessionDraft) throws -> ChatSession
    func fetchMessages(for sessionID: UUID) throws -> [ChatMessage]
    func appendMessage(_ message: ChatMessage, to sessionID: UUID) throws
    func deleteSession(id: UUID) throws
}

extension ChatStoring {
    func createSession(
        topic: LanguageTopic? = nil,
        defaultSystemPrompt: String = LanguageTopic.defaultSystemPrompt
    ) throws -> ChatSession {
        try createSession(from: ChatSessionDraft(topic: topic, defaultSystemPrompt: defaultSystemPrompt))
    }
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
