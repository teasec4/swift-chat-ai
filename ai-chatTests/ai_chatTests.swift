//
//  ai_chatTests.swift
//  ai-chatTests
//
//  Created by Максим Ковалев on 6/11/26.
//

import XCTest
@testable import ai_chat

@MainActor
final class ai_chatTests: XCTestCase {
    func testSendMessageAppendsUserAndAssistantMessages() async {
        let sut = ChatViewModel(
            messages: [],
            chatService: StubChatService(response: "Assistant answer")
        )

        await sut.sendMessage("  Hello, Swift  ")

        XCTAssertEqual(sut.messages.map(\.content), ["Hello, Swift", "Assistant answer"])
        XCTAssertEqual(sut.messages.map(\.role), [.user, .assistant])
        XCTAssertFalse(sut.isResponding)
    }

    func testSendMessageIgnoresEmptyContent() async {
        let sut = ChatViewModel(messages: [], chatService: StubChatService(response: "Ignored"))

        await sut.sendMessage(" \n\t ")

        XCTAssertTrue(sut.messages.isEmpty)
    }

    func testCanSendRespectsWhitespaceAndResponseState() async {
        let service = SuspendedChatService()
        let sut = ChatViewModel(messages: [], chatService: service)

        XCTAssertFalse(sut.canSend("   "))
        XCTAssertTrue(sut.canSend("Hello"))

        let task = Task {
            await sut.sendMessage("Hello")
        }

        await Task.yield()

        XCTAssertFalse(sut.canSend("Another message"))

        task.cancel()
        await task.value
    }

    func testSendMessageShowsFallbackWhenServiceFails() async {
        let sut = ChatViewModel(messages: [], chatService: FailingChatService())

        await sut.sendMessage("Hello")

        XCTAssertEqual(sut.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(sut.messages.last?.content, "Something went wrong. Please try again.")
    }

    func testSendMessageUsesLimitedRecentContext() async {
        let recorder = MessageRecorder()
        let sut = ChatViewModel(
            messages: [
                ChatMessage(content: "One", role: .user),
                ChatMessage(content: "Two", role: .assistant),
                ChatMessage(content: "Three", role: .user)
            ],
            chatService: RecordingChatService(recorder: recorder, response: "Four"),
            maxContextMessages: 3
        )

        await sut.sendMessage("Question")

        let sentMessages = await recorder.messages()
        XCTAssertEqual(sentMessages.map(\.content), ["Two", "Three", "Question"])
    }

    func testServiceErrorMessageIsNotStoredInNextContext() async {
        let service = FailingOnceChatService()
        let sut = ChatViewModel(messages: [], chatService: service)

        await sut.sendMessage("First question")
        await sut.sendMessage("Second question")

        let sentMessages = await service.messagesFromLastRequest()
        XCTAssertEqual(sentMessages.map(\.content), ["First question", "Second question"])
    }

    func testChatServiceRequiresHardcodedAPIKey() async {
        let service = ChatService()

        do {
            _ = try await service.response(for: [ChatMessage(content: "Hello", role: .user)])
            XCTFail("Expected missing API key error")
        } catch {
            XCTAssertEqual(error as? ChatServiceError, .missingAPIKey)
        }
    }
}

private struct StubChatService: ChatServing {
    let response: String

    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        response
    }
}

private struct FailingChatService: ChatServing {
    enum Failure: Error {
        case expected
    }

    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        throw Failure.expected
    }
}

private struct SuspendedChatService: ChatServing {
    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        try await Task.sleep(for: .seconds(30))
        return "Late response"
    }
}

private actor MessageRecorder {
    private var recordedMessages: [ChatMessage] = []

    func record(_ messages: [ChatMessage]) {
        recordedMessages = messages
    }

    func messages() -> [ChatMessage] {
        recordedMessages
    }
}

private struct RecordingChatService: ChatServing {
    let recorder: MessageRecorder
    let response: String

    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        await recorder.record(messages)
        return response
    }
}

private struct FailingOnceChatService: ChatServing {
    private let state = FailingOnceState()

    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        try await state.response(for: messages)
    }

    func messagesFromLastRequest() async -> [ChatMessage] {
        await state.messagesFromLastRequest()
    }
}

private actor FailingOnceState {
    private var requestCount = 0
    private var lastMessages: [ChatMessage] = []

    func response(for messages: [ChatMessage]) throws -> String {
        requestCount += 1
        lastMessages = messages

        if requestCount == 1 {
            throw FailingChatService.Failure.expected
        }

        return "Recovered"
    }

    func messagesFromLastRequest() -> [ChatMessage] {
        lastMessages
    }
}
