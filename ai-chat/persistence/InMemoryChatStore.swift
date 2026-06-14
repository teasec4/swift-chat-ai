//
//  InMemoryChatStore.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation

@MainActor
final class InMemoryChatStore: ChatStoring {
    private var sessions: [ChatSession]
    private var messagesBySessionID: [UUID: [ChatMessage]]

    init(sessions: [ChatSession] = [], messagesBySessionID: [UUID: [ChatMessage]] = [:]) {
        self.sessions = sessions
        self.messagesBySessionID = messagesBySessionID
    }

    func fetchSessions() throws -> [ChatSession] {
        sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createSession(topic: LanguageTopic? = nil) throws -> ChatSession {
        let session = ChatSession(
            title: topic?.title ?? ChatSession.defaultTitle,
            topicID: topic?.id,
            topicTitle: topic?.title,
            systemPrompt: topic?.systemPrompt ?? LanguageTopic.defaultSystemPrompt
        )
        sessions.insert(session, at: 0)
        messagesBySessionID[session.id] = []
        return session
    }

    func fetchMessages(for sessionID: UUID) throws -> [ChatMessage] {
        (messagesBySessionID[sessionID] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func appendMessage(_ message: ChatMessage, to sessionID: UUID) throws {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            throw ChatStoreError.sessionNotFound
        }

        let hadUserMessages = messagesBySessionID[sessionID, default: []].contains { $0.role == .user }
        messagesBySessionID[sessionID, default: []].append(message)
        sessions[index].updatedAt = message.createdAt

        if message.role == .user && hadUserMessages == false && sessions[index].title == ChatSession.defaultTitle {
            sessions[index].title = ChatSession.title(fromFirstMessage: message.content)
        }
    }

    func deleteSession(id: UUID) throws {
        sessions.removeAll { $0.id == id }
        messagesBySessionID.removeValue(forKey: id)
    }
}
