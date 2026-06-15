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
    private(set) var respondingSessionIDs: Set<ChatSession.ID> = []
    private(set) var partialResponsesBySessionID: [ChatSession.ID: String] = [:]
    private(set) var errorNoticesBySessionID: [ChatSession.ID: ChatErrorNotice] = [:]
    private(set) var generalErrorNotice: ChatErrorNotice?

    @ObservationIgnored private let chatStore: any ChatStoring
    @ObservationIgnored private let chatService: any ChatServing
    @ObservationIgnored private let networkAccessAuthorizer: any NetworkAccessAuthorizing
    @ObservationIgnored private let configuration: ChatFeatureConfiguration
    @ObservationIgnored private var responseTasksBySessionID: [ChatSession.ID: Task<AssistantResponse, Error>] = [:]
    @ObservationIgnored private var failedRequestsBySessionID: [ChatSession.ID: FailedAssistantRequest] = [:]

    init(
        chatStore: any ChatStoring,
        chatService: any ChatServing,
        networkAccessAuthorizer: any NetworkAccessAuthorizing,
        configuration: ChatFeatureConfiguration = .englishPractice
    ) {
        self.chatStore = chatStore
        self.chatService = chatService
        self.networkAccessAuthorizer = networkAccessAuthorizer
        self.configuration = configuration
    }

    var selectedSession: ChatSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    var topics: [LanguageTopic] {
        configuration.topics
    }

    var rolePlayScenarios: [RolePlayScenario] {
        configuration.rolePlayScenarios
    }

    var isResponding: Bool {
        respondingSessionIDs.isEmpty == false
    }

    var isSelectedSessionResponding: Bool {
        guard let selectedSessionID else { return false }
        return isResponding(in: selectedSessionID)
    }

    var selectedSessionError: ChatErrorNotice? {
        guard let selectedSessionID else { return generalErrorNotice }
        return errorNoticesBySessionID[selectedSessionID]
    }

    var selectedPartialResponse: String? {
        guard let selectedSessionID,
              let partialResponse = partialResponsesBySessionID[selectedSessionID],
              partialResponse.isEmpty == false
        else {
            return nil
        }

        return partialResponse
    }

    var hasApprovedNetworkAccess: Bool {
        networkAccessAuthorizer.hasUserApproval
    }

    func approveNetworkAccess() {
        networkAccessAuthorizer.approveNetworkAccess()
    }

    func prepareForNetworkedChat() async throws {
        try await networkAccessAuthorizer.prepareForNetworkUse()
    }

    func load() async {
        guard isLoading == false else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try refreshSessions()

            if sessions.isEmpty {
                let session = try chatStore.createSession(from: sessionDraft(topic: nil))
                try refreshSessions(selecting: session.id)
            }

            if selectedSessionID == nil {
                selectedSessionID = sessions.first?.id
            }

            try loadMessagesForSelectedSession()
            generalErrorNotice = nil
        } catch {
            showError(error, for: selectedSessionID, canRetry: false)
        }
    }

    func selectSession(_ sessionID: ChatSession.ID) async {
        guard selectedSessionID != sessionID else { return }

        selectedSessionID = sessionID

        do {
            try loadMessagesForSelectedSession()
        } catch {
            showError(error, for: sessionID, canRetry: false)
        }
    }

    @discardableResult
    func createSession(topic: LanguageTopic? = nil) async -> ChatSession.ID? {
        do {
            let session = try chatStore.createSession(from: sessionDraft(topic: topic))
            try refreshSessions(selecting: session.id)
            messages = []
            return session.id
        } catch {
            showError(error, for: selectedSessionID, canRetry: false)
            return nil
        }
    }

    @discardableResult
    func createSession(rolePlayScenario scenario: RolePlayScenario) async -> ChatSession.ID? {
        do {
            let session = try chatStore.createSession(from: sessionDraft(rolePlayScenario: scenario))
            try refreshSessions(selecting: session.id)
            messages = []
            return session.id
        } catch {
            showError(error, for: selectedSessionID, canRetry: false)
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

            let session = try chatStore.createSession(from: sessionDraft(topic: topic))
            try refreshSessions(selecting: session.id)
            messages = []
            return session.id
        } catch {
            showError(error, for: selectedSessionID, canRetry: false)
            return nil
        }
    }

    @discardableResult
    func openSession(for scenario: RolePlayScenario) async -> ChatSession.ID? {
        do {
            try refreshSessions()

            if let session = sessions.first(where: { $0.topicID == scenario.sessionTopicID }) {
                selectedSessionID = session.id
                try loadMessagesForSelectedSession()
                return session.id
            }

            let session = try chatStore.createSession(from: sessionDraft(rolePlayScenario: scenario))
            try refreshSessions(selecting: session.id)
            messages = []
            return session.id
        } catch {
            showError(error, for: selectedSessionID, canRetry: false)
            return nil
        }
    }

    func startConversation(in sessionID: ChatSession.ID) async {
        guard isResponding(in: sessionID) == false else { return }

        do {
            let storedMessages = try chatStore.fetchMessages(for: sessionID)
            guard storedMessages.isEmpty else { return }

            await requestAssistantResponse(for: sessionID, failedRequest: .opening)
        } catch {
            showError(error, for: sessionID, canRetry: false)
        }
    }

    func deleteSession(_ sessionID: ChatSession.ID) async {
        do {
            let wasSelected = selectedSessionID == sessionID
            cancelResponse(in: sessionID)
            clearError(for: sessionID)

            try chatStore.deleteSession(id: sessionID)
            try refreshSessions()

            if sessions.isEmpty {
                let session = try chatStore.createSession(from: sessionDraft(topic: nil))
                try refreshSessions(selecting: session.id)
                messages = []
                return
            }

            if wasSelected {
                selectedSessionID = sessions.first?.id
                try loadMessagesForSelectedSession()
            }
        } catch {
            showError(error, for: selectedSessionID, canRetry: false)
        }
    }

    func canSend(_ content: String) -> Bool {
        sanitizedContent(from: content).isEmpty == false && isSelectedSessionResponding == false
    }

    func sendMessage(_ content: String) async {
        let content = sanitizedContent(from: content)
        guard content.isEmpty == false else { return }

        var responseSessionID: ChatSession.ID?

        do {
            let sessionID = try selectedOrCreatedSessionID()
            responseSessionID = sessionID
            guard isResponding(in: sessionID) == false else { return }

            clearError(for: sessionID)
            let userMessage = ChatMessage(content: content, role: .user)

            try chatStore.appendMessage(userMessage, to: sessionID)
            if selectedSessionID == sessionID {
                messages.append(userMessage)
            }
            try refreshSessions(selecting: selectedSessionID)

            await requestAssistantResponse(for: sessionID, failedRequest: .latestMessages)
        } catch is CancellationError {
            return
        } catch {
            showError(error, for: responseSessionID, canRetry: false)
        }
    }

    func cancelResponseForSelectedSession() {
        guard let selectedSessionID else { return }
        cancelResponse(in: selectedSessionID)
    }

    func cancelResponse(in sessionID: ChatSession.ID) {
        responseTasksBySessionID[sessionID]?.cancel()
    }

    func retryFailedRequestForSelectedSession() async {
        guard let selectedSessionID else { return }
        await retryFailedRequest(in: selectedSessionID)
    }

    func retryFailedRequest(in sessionID: ChatSession.ID) async {
        guard let failedRequest = failedRequestsBySessionID[sessionID],
              isResponding(in: sessionID) == false
        else {
            return
        }

        clearError(for: sessionID)
        await requestAssistantResponse(for: sessionID, failedRequest: failedRequest)
    }

    func dismissErrorForSelectedSession() {
        guard let selectedSessionID else {
            generalErrorNotice = nil
            return
        }

        clearError(for: selectedSessionID)
    }

    private func selectedOrCreatedSessionID() throws -> ChatSession.ID {
        if let selectedSessionID {
            return selectedSessionID
        }

        let session = try chatStore.createSession(from: sessionDraft(topic: nil))
        try refreshSessions(selecting: session.id)
        return session.id
    }

    func topic(for session: ChatSession?) -> LanguageTopic? {
        configuration.topic(for: session)
    }

    func rolePlayScenario(for session: ChatSession?) -> RolePlayScenario? {
        configuration.rolePlayScenario(for: session)
    }

    func isResponding(in sessionID: ChatSession.ID) -> Bool {
        respondingSessionIDs.contains(sessionID)
    }

    private func systemPrompt(for sessionID: ChatSession.ID) -> String {
        sessions.first { $0.id == sessionID }?.systemPrompt ?? configuration.defaultSystemPrompt
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
        return Array(storedMessages.suffix(configuration.maxContextMessages))
    }

    private func makeContext(for failedRequest: FailedAssistantRequest, sessionID: ChatSession.ID) throws -> [ChatMessage] {
        switch failedRequest {
        case .opening:
            [ChatMessage(content: openingRequest(for: sessionID), role: .user)]
        case .latestMessages:
            try recentContext(for: sessionID)
        }
    }

    private func openingRequest(for sessionID: ChatSession.ID) -> String {
        let session = sessions.first { $0.id == sessionID }

        if let rolePlayScenario = configuration.rolePlayScenario(for: session) {
            return rolePlayScenario.openingRequest
        }

        if let topicID = session?.topicID,
           RolePlayScenario.isRolePlayTopicID(topicID) {
            return RolePlayScenario.genericOpeningRequest
        }

        return configuration.openingRequest
    }

    private func sessionDraft(topic: LanguageTopic?) -> ChatSessionDraft {
        ChatSessionDraft(topic: topic, defaultSystemPrompt: configuration.defaultSystemPrompt)
    }

    private func sessionDraft(rolePlayScenario scenario: RolePlayScenario) -> ChatSessionDraft {
        ChatSessionDraft(rolePlayScenario: scenario)
    }

    private func requestAssistantResponse(
        for sessionID: ChatSession.ID,
        failedRequest: FailedAssistantRequest
    ) async {
        guard isResponding(in: sessionID) == false else { return }

        let context: [ChatMessage]
        do {
            context = try makeContext(for: failedRequest, sessionID: sessionID)
        } catch {
            showError(error, for: sessionID, canRetry: true, failedRequest: failedRequest)
            return
        }

        let correctionTarget = correctionTargetMessageContent(for: failedRequest, in: context)
        let systemPrompt = systemPrompt(for: sessionID)
        let task = Task {
            var emptyResponseRetriesRemaining = 1

            while true {
                do {
                    var completedResponse: AssistantResponse?

                    for try await event in chatService.responseEvents(for: context, systemPrompt: systemPrompt) {
                        try Task.checkCancellation()

                        switch event {
                        case let .partial(content):
                            await MainActor.run {
                                partialResponsesBySessionID[sessionID] = content
                            }
                        case let .completed(response):
                            completedResponse = response.keepingCorrections(for: correctionTarget)
                        }
                    }

                    try Task.checkCancellation()

                    guard let completedResponse else {
                        throw ChatResponseStreamError.missingCompletedResponse
                    }

                    return completedResponse
                } catch ChatServiceError.emptyResponse where emptyResponseRetriesRemaining > 0 {
                    emptyResponseRetriesRemaining -= 1
                    await MainActor.run {
                        partialResponsesBySessionID[sessionID] = nil
                    }

                    do {
                        return try await chatService
                            .response(for: context, systemPrompt: systemPrompt)
                            .keepingCorrections(for: correctionTarget)
                    } catch ChatServiceError.emptyResponse {
                        continue
                    }
                }
            }
        }
        responseTasksBySessionID[sessionID] = task
        respondingSessionIDs.insert(sessionID)

        let assistantResponse: AssistantResponse
        do {
            assistantResponse = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch is CancellationError {
            clearResponseTask(for: sessionID)
            return
        } catch {
            clearResponseTask(for: sessionID)
            showError(error, for: sessionID, canRetry: true, failedRequest: failedRequest)
            return
        }

        clearResponseTask(for: sessionID)
        appendAssistantResponse(assistantResponse, to: sessionID)
    }

    private func correctionTargetMessageContent(
        for failedRequest: FailedAssistantRequest,
        in context: [ChatMessage]
    ) -> String? {
        switch failedRequest {
        case .opening:
            nil
        case .latestMessages:
            context.last { $0.role == .user }?.content
        }
    }

    private func appendAssistantResponse(_ assistantResponse: AssistantResponse, to sessionID: ChatSession.ID) {
        let assistantMessage = ChatMessage(
            content: assistantResponse.reply,
            role: .assistant,
            corrections: assistantResponse.corrections
        )

        do {
            try chatStore.appendMessage(assistantMessage, to: sessionID)
            try refreshSessions(selecting: selectedSessionID)

            if selectedSessionID == sessionID {
                try loadMessagesForSelectedSession()
            }

            clearError(for: sessionID)
        } catch {
            showError(error, for: sessionID, canRetry: false)
        }
    }

    private func clearResponseTask(for sessionID: ChatSession.ID) {
        responseTasksBySessionID[sessionID] = nil
        respondingSessionIDs.remove(sessionID)
        partialResponsesBySessionID[sessionID] = nil
    }

    private func showError(
        _ error: Error,
        for sessionID: ChatSession.ID?,
        canRetry: Bool,
        failedRequest: FailedAssistantRequest? = nil
    ) {
        let notice = ChatErrorNotice(message: errorMessage(for: error), canRetry: canRetry)

        guard let sessionID else {
            generalErrorNotice = notice
            return
        }

        errorNoticesBySessionID[sessionID] = notice

        if canRetry, let failedRequest {
            failedRequestsBySessionID[sessionID] = failedRequest
        } else {
            failedRequestsBySessionID[sessionID] = nil
        }
    }

    private func clearError(for sessionID: ChatSession.ID) {
        errorNoticesBySessionID[sessionID] = nil
        failedRequestsBySessionID[sessionID] = nil
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

private enum FailedAssistantRequest: Sendable {
    case opening
    case latestMessages
}
