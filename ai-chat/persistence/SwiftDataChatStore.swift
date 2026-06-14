//
//  SwiftDataChatStore.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataChatStore: ChatStoring {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSessions() throws -> [ChatSession] {
        var descriptor = FetchDescriptor<ChatSessionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.includePendingChanges = true

        return try modelContext.fetch(descriptor).map(ChatSession.init(record:))
    }

    func createSession(topic: LanguageTopic? = nil) throws -> ChatSession {
        let session = ChatSessionRecord(
            title: topic?.title ?? ChatSession.defaultTitle,
            topicID: topic?.id,
            topicTitle: topic?.title,
            systemPrompt: topic?.systemPrompt ?? LanguageTopic.defaultSystemPrompt
        )
        modelContext.insert(session)
        try modelContext.save()
        return ChatSession(record: session)
    }

    func fetchMessages(for sessionID: UUID) throws -> [ChatMessage] {
        try sessionRecord(for: sessionID)
            .messages
            .sorted { $0.createdAt < $1.createdAt }
            .map(ChatMessage.init(record:))
    }

    func appendMessage(_ message: ChatMessage, to sessionID: UUID) throws {
        let session = try sessionRecord(for: sessionID)
        let hadUserMessages = session.messages.contains { $0.roleRawValue == ChatMessage.Role.user.rawValue }
        let record = ChatMessageRecord(
            id: message.id,
            content: message.content,
            role: message.role,
            createdAt: message.createdAt,
            session: session
        )

        session.messages.append(record)
        session.updatedAt = message.createdAt

        if message.role == .user && hadUserMessages == false && session.title == ChatSession.defaultTitle {
            session.title = ChatSession.title(fromFirstMessage: message.content)
        }

        modelContext.insert(record)
        try modelContext.save()
    }

    func deleteSession(id: UUID) throws {
        let session = try sessionRecord(for: id)
        modelContext.delete(session)
        try modelContext.save()
    }

    private func sessionRecord(for id: UUID) throws -> ChatSessionRecord {
        var descriptor = FetchDescriptor<ChatSessionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        guard let session = try modelContext.fetch(descriptor).first else {
            throw ChatStoreError.sessionNotFound
        }

        return session
    }
}
