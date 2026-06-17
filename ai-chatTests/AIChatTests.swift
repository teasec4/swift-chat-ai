//
//  AIChatTests.swift
//  ai-chatTests
//
//  Created by Максим Ковалев on 6/11/26.
//

import SwiftData
import XCTest
@testable import ai_chat

@MainActor
final class AIChatTests: XCTestCase {
    func testLoadCreatesInitialSession() async {
        let sut = makeViewModel()

        await sut.load()

        XCTAssertEqual(sut.sessions.count, 1)
        XCTAssertNotNil(sut.selectedSessionID)
        XCTAssertTrue(sut.messages.isEmpty)
    }

    func testSendMessageAppendsUserAndAssistantMessages() async {
        let sut = makeViewModel(chatService: StubChatService(response: "Assistant answer"))

        await sut.load()
        await sut.sendMessage("  Hello, Swift  ")

        XCTAssertEqual(sut.messages.map(\.content), ["Hello, Swift", "Assistant answer"])
        XCTAssertEqual(sut.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(sut.sessions.first?.title, "Hello, Swift")
        XCTAssertFalse(sut.isResponding)
    }

    func testSendMessageAppendsAssistantCorrections() async {
        let correction = MessageCorrection(
            original: "I very like hiking",
            corrected: "I really like hiking",
            type: "grammar",
            explanation: "Use really before like."
        )
        let sut = makeViewModel(
            chatService: StubChatService(response: "Nice! Where do you usually hike?", corrections: [correction])
        )

        await sut.load()
        await sut.sendMessage("I very like hiking")

        XCTAssertEqual(sut.messages.last?.content, "Nice! Where do you usually hike?")
        XCTAssertEqual(sut.messages.last?.corrections, [correction])
    }

    func testSendMessageIgnoresEmptyContent() async {
        let sut = makeViewModel(chatService: StubChatService(response: "Ignored"))

        await sut.load()
        await sut.sendMessage(" \n\t ")

        XCTAssertTrue(sut.messages.isEmpty)
    }

    func testCanSendRespectsWhitespaceAndResponseState() async {
        let service = SuspendedChatService()
        let sut = makeViewModel(chatService: service)

        await sut.load()

        XCTAssertFalse(sut.canSend("   "))
        XCTAssertTrue(sut.canSend("Hello"))

        let task = Task {
            await sut.sendMessage("Hello")
        }

        await waitUntil { sut.isResponding }
        XCTAssertFalse(sut.canSend("Another message"))

        task.cancel()
        await task.value
    }

    func testSendMessageShowsFallbackWhenServiceFails() async {
        let sut = makeViewModel(chatService: FailingChatService())

        await sut.load()
        await sut.sendMessage("Hello")

        XCTAssertEqual(sut.messages.map(\.role), [.user])
        XCTAssertEqual(sut.messages.map(\.content), ["Hello"])
        XCTAssertEqual(sut.selectedSessionError?.message, "Something went wrong. Please try again.")
        XCTAssertEqual(sut.selectedSessionError?.canRetry, true)
    }

    func testRetryFailedMessageDoesNotDuplicateUserMessage() async {
        let service = FailingOnceChatService()
        let sut = makeViewModel(chatService: service)

        await sut.load()
        await sut.sendMessage("First question")

        XCTAssertEqual(sut.messages.map(\.content), ["First question"])
        XCTAssertNotNil(sut.selectedSessionError)

        await sut.retryFailedRequestForSelectedSession()

        XCTAssertEqual(sut.messages.map(\.content), ["First question", "Recovered"])
        XCTAssertEqual(sut.messages.map(\.role), [.user, .assistant])
        XCTAssertNil(sut.selectedSessionError)
    }

    func testCancelResponseLeavesUserMessageWithoutError() async {
        let sut = makeViewModel(chatService: SuspendedChatService())

        await sut.load()

        let task = Task {
            await sut.sendMessage("Please answer later")
        }

        await waitUntil { sut.isSelectedSessionResponding }
        sut.cancelResponseForSelectedSession()
        await task.value

        XCTAssertFalse(sut.isResponding)
        XCTAssertEqual(sut.messages.map(\.content), ["Please answer later"])
        XCTAssertNil(sut.selectedSessionError)
    }

    func testSwitchingSessionsScopesResponseState() async {
        let sut = makeViewModel(chatService: SuspendedChatService())

        await sut.load()
        guard let firstSessionID = sut.selectedSessionID else {
            XCTFail("Expected initial session")
            return
        }

        let task = Task {
            await sut.sendMessage("Answer in the first session")
        }

        await waitUntil { sut.isResponding(in: firstSessionID) }
        let secondSessionID = await sut.createSession()

        XCTAssertEqual(sut.selectedSessionID, secondSessionID)
        XCTAssertTrue(sut.isResponding(in: firstSessionID))
        XCTAssertFalse(sut.isSelectedSessionResponding)
        XCTAssertTrue(sut.canSend("Message in the selected session"))

        sut.cancelResponse(in: firstSessionID)
        await task.value
    }

    func testSendMessageUsesLimitedRecentContext() async {
        let recorder = MessageRecorder()
        let session = ChatSession(title: "Existing chat")
        let store = InMemoryChatStore(
            sessions: [session],
            messagesBySessionID: [
                session.id: [
                    ChatMessage(content: "One", role: .user),
                    ChatMessage(content: "Two", role: .assistant),
                    ChatMessage(content: "Three", role: .user)
                ]
            ]
        )
        let sut = ChatViewModel(
            chatStore: store,
            chatService: RecordingChatService(recorder: recorder, response: "Four"),
            configuration: ChatFeatureConfiguration(maxContextMessages: 3)
        )

        await sut.load()
        await sut.sendMessage("Question")

        let sentMessages = await recorder.messages()
        XCTAssertEqual(sentMessages.map(\.content), ["Two", "Three", "Question"])
    }

    func testTopicSessionPassesTopicPromptToService() async {
        let recorder = MessageRecorder()
        let topic = LanguageTopic.all[1]
        let sut = makeViewModel(
            chatService: RecordingChatService(recorder: recorder, response: "Topic answer")
        )

        await sut.load()
        await sut.createSession(topic: topic)
        await sut.sendMessage("Let's practice")

        XCTAssertEqual(sut.selectedSession?.topicID, topic.id)
        XCTAssertEqual(sut.selectedSession?.topicTitle, topic.title)

        let sentPrompt = await recorder.systemPrompt()
        XCTAssertEqual(sentPrompt, topic.systemPrompt)
    }

    func testOpenSessionForTopicReusesLatestExistingSession() async {
        let recorder = MessageRecorder()
        let topic = LanguageTopic.all[4]
        let olderDate = Date(timeIntervalSince1970: 1)
        let latestDate = Date(timeIntervalSince1970: 2)
        let olderSession = ChatSession(
            title: "Old Hobbies",
            topicID: topic.id,
            topicTitle: topic.title,
            systemPrompt: topic.systemPrompt,
            createdAt: olderDate,
            updatedAt: olderDate
        )
        let latestSession = ChatSession(
            title: "Latest Hobbies",
            topicID: topic.id,
            topicTitle: topic.title,
            systemPrompt: topic.systemPrompt,
            createdAt: latestDate,
            updatedAt: latestDate
        )
        let latestMessage = ChatMessage(
            content: "Hi! What do you like doing after work?",
            role: .assistant,
            createdAt: latestDate
        )
        let store = InMemoryChatStore(
            sessions: [olderSession, latestSession],
            messagesBySessionID: [
                olderSession.id: [
                    ChatMessage(content: "Older answer", role: .assistant, createdAt: olderDate)
                ],
                latestSession.id: [latestMessage]
            ]
        )
        let sut = makeViewModel(
            store: store,
            chatService: RecordingChatService(recorder: recorder, response: "Should not be used")
        )

        await sut.load()
        let openedSessionID = await sut.openSession(for: topic)
        await sut.startConversation(in: latestSession.id)

        XCTAssertEqual(openedSessionID, latestSession.id)
        XCTAssertEqual(sut.selectedSessionID, latestSession.id)
        XCTAssertEqual(sut.messages, [latestMessage])
        XCTAssertEqual(sut.sessions.filter { $0.topicID == topic.id }.count, 2)

        let requestCount = await recorder.requestCount()
        XCTAssertEqual(requestCount, 0)
    }

    func testOpenSessionForTopicCreatesMissingSessionOnlyOnce() async {
        let topic = LanguageTopic.all[4]
        let sut = makeViewModel()

        await sut.load()
        let firstSessionID = await sut.openSession(for: topic)
        let sessionCountAfterFirstOpen = sut.sessions.count
        let secondSessionID = await sut.openSession(for: topic)

        XCTAssertEqual(firstSessionID, secondSessionID)
        XCTAssertEqual(sut.sessions.count, sessionCountAfterFirstOpen)
        XCTAssertEqual(sut.sessions.filter { $0.topicID == topic.id }.count, 1)
    }

    func testCreatingTopicSessionKeepsPreviousTopicSessionInHistory() async {
        let topic = LanguageTopic.all[4]
        let sut = makeViewModel()

        await sut.load()
        let firstSessionID = await sut.createSession(topic: topic)
        let secondSessionID = await sut.createSession(topic: topic)

        XCTAssertNotNil(firstSessionID)
        XCTAssertNotNil(secondSessionID)
        XCTAssertNotEqual(firstSessionID, secondSessionID)
        XCTAssertEqual(sut.sessions.filter { $0.topicID == topic.id }.count, 2)
    }

    func testTopicSessionStartsWithAssistantOpeningQuestion() async {
        let recorder = MessageRecorder()
        let topic = LanguageTopic.all[2]
        let sut = makeViewModel(
            chatService: RecordingChatService(recorder: recorder, response: "Hi! What food do you like to cook?")
        )

        await sut.load()
        guard let sessionID = await sut.createSession(topic: topic) else {
            XCTFail("Expected topic session")
            return
        }

        await sut.startConversation(in: sessionID)

        XCTAssertEqual(sut.messages.map(\.role), [.assistant])
        XCTAssertEqual(sut.messages.map(\.content), ["Hi! What food do you like to cook?"])

        let sentMessages = await recorder.messages()
        let sentPrompt = await recorder.systemPrompt()
        XCTAssertEqual(sentMessages.map(\.content), [LanguageTopic.openingRequest])
        XCTAssertEqual(sentPrompt, topic.systemPrompt)
    }

    func testStartConversationUsesConfiguredOpeningRequestAndTopics() async {
        let recorder = MessageRecorder()
        let topic = LanguageTopic(
            id: "custom-topic",
            title: "Custom Topic",
            subtitle: "Injected from host app",
            iconName: "bubble.left",
            systemPrompt: "Practice a custom host-app topic."
        )
        let configuration = ChatFeatureConfiguration(
            topics: [topic],
            defaultSystemPrompt: "Practice with the host app default prompt.",
            openingRequest: "Open the custom topic.",
            maxContextMessages: 12
        )
        let sut = makeViewModel(
            chatService: RecordingChatService(recorder: recorder, response: "Custom opening"),
            configuration: configuration
        )

        XCTAssertEqual(sut.topics, [topic])

        await sut.load()
        guard let sessionID = await sut.createSession(topic: topic) else {
            XCTFail("Expected topic session")
            return
        }

        await sut.startConversation(in: sessionID)

        let sentMessages = await recorder.messages()
        let sentPrompt = await recorder.systemPrompt()
        XCTAssertEqual(sentMessages.map(\.content), ["Open the custom topic."])
        XCTAssertEqual(sentPrompt, topic.systemPrompt)
    }

    func testStartConversationDoesNotDuplicateOpeningMessage() async {
        let recorder = MessageRecorder()
        let topic = LanguageTopic.all[3]
        let sut = makeViewModel(
            chatService: RecordingChatService(recorder: recorder, response: "Hi! What do you do for work?")
        )

        await sut.load()
        guard let sessionID = await sut.createSession(topic: topic) else {
            XCTFail("Expected topic session")
            return
        }

        await sut.startConversation(in: sessionID)
        await sut.startConversation(in: sessionID)

        XCTAssertEqual(sut.messages.count, 1)

        let requestCount = await recorder.requestCount()
        XCTAssertEqual(requestCount, 1)
    }

    func testDefaultSessionUsesTeacherPrompt() async {
        let recorder = MessageRecorder()
        let sut = makeViewModel(
            chatService: RecordingChatService(recorder: recorder, response: "Default answer")
        )

        await sut.load()
        await sut.sendMessage("Hello")

        let sentPrompt = await recorder.systemPrompt()
        XCTAssertEqual(sentPrompt, LanguageTopic.defaultSystemPrompt)
    }

    func testDefaultSessionUsesConfiguredPrompt() async {
        let recorder = MessageRecorder()
        let configuration = ChatFeatureConfiguration(
            topics: [],
            defaultSystemPrompt: "Practice with a host-app default prompt.",
            openingRequest: "Start.",
            maxContextMessages: 12
        )
        let sut = makeViewModel(
            chatService: RecordingChatService(recorder: recorder, response: "Configured answer"),
            configuration: configuration
        )

        await sut.load()
        await sut.sendMessage("Hello")

        let sentPrompt = await recorder.systemPrompt()
        XCTAssertEqual(sentPrompt, "Practice with a host-app default prompt.")
    }

    func testServiceErrorMessageIsNotStoredInNextContext() async {
        let service = FailingOnceChatService()
        let sut = makeViewModel(chatService: service)

        await sut.load()
        await sut.sendMessage("First question")
        await sut.sendMessage("Second question")

        let sentMessages = await service.messagesFromLastRequest()
        XCTAssertEqual(sentMessages.map(\.content), ["First question", "Second question"])
    }

    func testCreateAndDeleteSessions() async {
        let sut = makeViewModel()

        await sut.load()
        let firstSessionID = sut.selectedSessionID

        await sut.createSession()
        XCTAssertEqual(sut.sessions.count, 2)
        XCTAssertNotEqual(sut.selectedSessionID, firstSessionID)

        guard let firstSessionID else {
            XCTFail("Expected initial session")
            return
        }

        await sut.deleteSession(firstSessionID)
        XCTAssertEqual(sut.sessions.count, 1)
        XCTAssertNotEqual(sut.selectedSessionID, firstSessionID)
    }

    func testSwiftDataStorePersistsSessionsAndMessages() throws {
        let container = try makeInMemoryModelContainer()
        let sessionStore = SwiftDataChatStore(modelContext: ModelContext(container))
        let session = try sessionStore.createSession()
        let message = ChatMessage(content: "Persist this", role: .user)

        try sessionStore.appendMessage(message, to: session.id)

        let reloadedStore = SwiftDataChatStore(modelContext: ModelContext(container))
        let sessions = try reloadedStore.fetchSessions()
        let messages = try reloadedStore.fetchMessages(for: session.id)

        XCTAssertEqual(sessions.map(\.id), [session.id])
        XCTAssertEqual(sessions.first?.title, "Persist this")
        XCTAssertEqual(messages, [message])
    }

    func testSwiftDataStorePersistsMessageCorrections() throws {
        let container = try makeInMemoryModelContainer()
        let sessionStore = SwiftDataChatStore(modelContext: ModelContext(container))
        let session = try sessionStore.createSession()
        let correction = MessageCorrection(
            original: "I am agree",
            corrected: "I agree",
            type: "grammar",
            explanation: "Agree is already a verb."
        )
        let message = ChatMessage(
            content: "Good answer. What else do you think?",
            role: .assistant,
            corrections: [correction]
        )

        try sessionStore.appendMessage(message, to: session.id)

        let reloadedStore = SwiftDataChatStore(modelContext: ModelContext(container))
        let messages = try reloadedStore.fetchMessages(for: session.id)

        XCTAssertEqual(messages.first?.corrections, [correction])
    }

    func testChatServiceErrorDescriptions() {
        XCTAssertNotNil(ChatServiceError.missingAPIKey.errorDescription)
        XCTAssertNotNil(ChatServiceError.invalidResponse.errorDescription)
        XCTAssertNotNil(ChatServiceError.emptyResponse.errorDescription)
        XCTAssertEqual(
            ChatServiceError.httpFailure(statusCode: 429).errorDescription,
            "The AI service returned HTTP 429."
        )
    }

    func testAssistantResponseDecodesStructuredJSON() {
        let rawResponse = """
        {
          "reply": "Nice! What games do you usually play?",
          "corrections": [
            {
              "original": "I very like games",
              "corrected": "I really like games",
              "type": "grammar",
              "explanation": "Use really before like."
            }
          ]
        }
        """

        let response = AssistantResponse.make(from: rawResponse)

        XCTAssertEqual(response?.reply, "Nice! What games do you usually play?")
        XCTAssertEqual(
            response?.corrections,
            [
                MessageCorrection(
                    original: "I very like games",
                    corrected: "I really like games",
                    type: "grammar",
                    explanation: "Use really before like."
                )
            ]
        )
    }

    func testAssistantResponseFallsBackToPlainText() {
        let response = AssistantResponse.make(from: "Sure, let's keep practicing.")

        XCTAssertEqual(response?.reply, "Sure, let's keep practicing.")
        XCTAssertEqual(response?.corrections, [])
    }

    private func makeViewModel(
        chatService: any ChatServing = StubChatService(response: "OK"),
        configuration: ChatFeatureConfiguration = .englishPractice
    ) -> ChatViewModel {
        makeViewModel(
            store: InMemoryChatStore(),
            chatService: chatService,
            configuration: configuration
        )
    }

    private func makeViewModel(
        store: any ChatStoring,
        chatService: any ChatServing = StubChatService(response: "OK"),
        configuration: ChatFeatureConfiguration = .englishPractice
    ) -> ChatViewModel {
        ChatViewModel(
            chatStore: store,
            chatService: chatService,
            configuration: configuration
        )
    }

    private func makeInMemoryModelContainer() throws -> ModelContainer {
        let schema = Schema([
            ChatSessionRecord.self,
            ChatMessageRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<20 where condition() == false {
            await Task.yield()
        }

        XCTAssertTrue(condition(), file: file, line: line)
    }

}

private struct StubChatService: ChatServing {
    let response: AssistantResponse

    init(response: String, corrections: [MessageCorrection] = []) {
        self.response = AssistantResponse(reply: response, corrections: corrections)
    }

    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        response
    }
}

private struct FailingChatService: ChatServing {
    enum Failure: Error {
        case expected
    }

    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        throw Failure.expected
    }
}

private struct SuspendedChatService: ChatServing {
    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        try await Task.sleep(for: .seconds(30))
        return AssistantResponse(reply: "Late response")
    }
}

private actor MessageRecorder {
    private var recordedMessages: [ChatMessage] = []
    private var recordedSystemPrompt = ""
    private var recordedRequestCount = 0

    func record(_ messages: [ChatMessage], systemPrompt: String) {
        recordedMessages = messages
        recordedSystemPrompt = systemPrompt
        recordedRequestCount += 1
    }

    func messages() -> [ChatMessage] {
        recordedMessages
    }

    func systemPrompt() -> String {
        recordedSystemPrompt
    }

    func requestCount() -> Int {
        recordedRequestCount
    }
}

private struct RecordingChatService: ChatServing {
    let recorder: MessageRecorder
    let response: String

    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        await recorder.record(messages, systemPrompt: systemPrompt)
        return AssistantResponse(reply: response)
    }
}

private struct FailingOnceChatService: ChatServing {
    private let state = FailingOnceState()

    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        try await state.response(for: messages)
    }

    func messagesFromLastRequest() async -> [ChatMessage] {
        await state.messagesFromLastRequest()
    }
}

private actor FailingOnceState {
    private var requestCount = 0
    private var lastMessages: [ChatMessage] = []

    func response(for messages: [ChatMessage]) throws -> AssistantResponse {
        requestCount += 1
        lastMessages = messages

        if requestCount == 1 {
            throw FailingChatService.Failure.expected
        }

        return AssistantResponse(reply: "Recovered")
    }

    func messagesFromLastRequest() -> [ChatMessage] {
        lastMessages
    }
}
