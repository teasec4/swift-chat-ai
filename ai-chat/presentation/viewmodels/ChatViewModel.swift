//
//  ChatViewModel.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    private(set) var sessions: [ChatSession] = []
    private(set) var messages: [ChatMessage] = []
    private(set) var selectedSessionID: ChatSession.ID?
    private(set) var isLoading = false
    private(set) var isResponding = false

    @ObservationIgnored private let chatStore: any ChatStoring
    @ObservationIgnored private let chatService: any ChatServing
    @ObservationIgnored private let maxContextMessages: Int

    init(
        chatStore: any ChatStoring,
        chatService: any ChatServing,
        maxContextMessages: Int = 12
    ) {
        self.chatStore = chatStore
        self.chatService = chatService
        self.maxContextMessages = maxContextMessages
    }

    var selectedSession: ChatSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    func load() async {
        guard isLoading == false else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try refreshSessions()

            if sessions.isEmpty {
                let session = try chatStore.createSession(topic: nil)
                try refreshSessions(selecting: session.id)
            }

            if selectedSessionID == nil {
                selectedSessionID = sessions.first?.id
            }

            try loadMessagesForSelectedSession()
        } catch {
            showTransientError(error)
        }
    }

    func selectSession(_ sessionID: ChatSession.ID) async {
        guard selectedSessionID != sessionID else { return }

        selectedSessionID = sessionID

        do {
            try loadMessagesForSelectedSession()
        } catch {
            showTransientError(error)
        }
    }

    @discardableResult
    func createSession(topic: LanguageTopic? = nil) async -> ChatSession.ID? {
        do {
            let session = try chatStore.createSession(topic: topic)
            try refreshSessions(selecting: session.id)
            messages = []
            return session.id
        } catch {
            showTransientError(error)
            return nil
        }
    }

    @discardableResult
    func openSession(for topic: LanguageTopic) async -> ChatSession.ID? {
        do {
            try refreshSessions()

            if let session = sessions.first(where: { $0.topicID == topic.id }) {
                selectedSessionID = session.id
                try loadMessagesForSelectedSession()
                return session.id
            }

            let session = try chatStore.createSession(topic: topic)
            try refreshSessions(selecting: session.id)
            messages = []
            return session.id
        } catch {
            showTransientError(error)
            return nil
        }
    }

    func startConversation(in sessionID: ChatSession.ID) async {
        guard isResponding == false else { return }

        do {
            let storedMessages = try chatStore.fetchMessages(for: sessionID)
            guard storedMessages.isEmpty else { return }

            let systemPrompt = systemPrompt(for: sessionID)
            let openingRequest = ChatMessage(
                content: LanguageTopic.openingRequest,
                role: .user
            )

            isResponding = true
            defer { isResponding = false }

            let assistantContent = try await chatService.response(
                for: [openingRequest],
                systemPrompt: systemPrompt
            )
            let assistantMessage = ChatMessage(content: assistantContent, role: .assistant)

            try chatStore.appendMessage(assistantMessage, to: sessionID)
            try refreshSessions(selecting: selectedSessionID)

            if selectedSessionID == sessionID {
                messages.append(assistantMessage)
            }
        } catch is CancellationError {
            return
        } catch {
            showTransientError(error, for: sessionID)
        }
    }

    func deleteSession(_ sessionID: ChatSession.ID) async {
        do {
            let wasSelected = selectedSessionID == sessionID
            try chatStore.deleteSession(id: sessionID)
            try refreshSessions()

            if sessions.isEmpty {
                let session = try chatStore.createSession(topic: nil)
                try refreshSessions(selecting: session.id)
                messages = []
                return
            }

            if wasSelected {
                selectedSessionID = sessions.first?.id
                try loadMessagesForSelectedSession()
            }
        } catch {
            showTransientError(error)
        }
    }

    func canSend(_ content: String) -> Bool {
        sanitizedContent(from: content).isEmpty == false && isResponding == false
    }

    func sendMessage(_ content: String) async {
        let content = sanitizedContent(from: content)
        guard content.isEmpty == false, isResponding == false else { return }

        var responseSessionID: ChatSession.ID?

        do {
            let sessionID = try selectedOrCreatedSessionID()
            responseSessionID = sessionID
            let systemPrompt = systemPrompt(for: sessionID)
            let userMessage = ChatMessage(content: content, role: .user)

            try chatStore.appendMessage(userMessage, to: sessionID)
            if selectedSessionID == sessionID {
                messages.append(userMessage)
            }
            try refreshSessions(selecting: selectedSessionID)

            isResponding = true
            defer { isResponding = false }

            let context = try recentContext(for: sessionID)
            let assistantContent = try await chatService.response(
                for: context,
                systemPrompt: systemPrompt
            )
            let assistantMessage = ChatMessage(content: assistantContent, role: .assistant)

            try chatStore.appendMessage(assistantMessage, to: sessionID)
            try refreshSessions(selecting: selectedSessionID)

            if selectedSessionID == sessionID {
                messages.append(assistantMessage)
            }
        } catch is CancellationError {
            return
        } catch {
            showTransientError(error, for: responseSessionID)
        }
    }

    private func selectedOrCreatedSessionID() throws -> ChatSession.ID {
        if let selectedSessionID {
            return selectedSessionID
        }

        let session = try chatStore.createSession(topic: nil)
        try refreshSessions(selecting: session.id)
        return session.id
    }

    private func systemPrompt(for sessionID: ChatSession.ID) -> String {
        sessions.first { $0.id == sessionID }?.systemPrompt ?? LanguageTopic.defaultSystemPrompt
    }

    private func refreshSessions(selecting preferredSessionID: ChatSession.ID? = nil) throws {
        let fetchedSessions = try chatStore.fetchSessions()
        sessions = fetchedSessions

        if let preferredSessionID, fetchedSessions.contains(where: { $0.id == preferredSessionID }) {
            selectedSessionID = preferredSessionID
            return
        }

        if let selectedSessionID, fetchedSessions.contains(where: { $0.id == selectedSessionID }) {
            return
        }

        selectedSessionID = fetchedSessions.first?.id
    }

    private func loadMessagesForSelectedSession() throws {
        guard let selectedSessionID else {
            messages = []
            return
        }

        messages = try chatStore.fetchMessages(for: selectedSessionID)
    }

    private func recentContext(for sessionID: ChatSession.ID) throws -> [ChatMessage] {
        let storedMessages = try chatStore.fetchMessages(for: sessionID)
        return Array(storedMessages.suffix(maxContextMessages))
    }

    private func showTransientError(_ error: Error, for sessionID: ChatSession.ID?) {
        guard sessionID == selectedSessionID else { return }
        messages.append(ChatMessage(content: errorMessage(for: error), role: .assistant))
    }

    private func showTransientError(_ error: Error) {
        messages.append(ChatMessage(content: errorMessage(for: error), role: .assistant))
    }

    private func sanitizedContent(from content: String) -> String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case let localizedError as LocalizedError:
            localizedError.errorDescription ?? "Something went wrong. Please try again."
        default:
            "Something went wrong. Please try again."
        }
    }
}
