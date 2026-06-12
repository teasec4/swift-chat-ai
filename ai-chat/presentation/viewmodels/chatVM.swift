//
//  chatVM.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage]
    private(set) var isResponding = false

    @ObservationIgnored private var chatService: any ChatServing
    @ObservationIgnored private var contextStore: ChatContextStore

    init(
        messages: [ChatMessage] = [],
        chatService: any ChatServing = ChatService(),
        maxContextMessages: Int = 12
    ) {
        self.messages = messages
        self.chatService = chatService
        self.contextStore = ChatContextStore(messages: messages, maxMessages: maxContextMessages)
    }

    func canSend(_ content: String) -> Bool {
        sanitizedContent(from: content).isEmpty == false && isResponding == false
    }

    func sendMessage(_ content: String) async {
        guard let userMessage = appendMessage(content, role: .user, storesInContext: true) else { return }

        isResponding = true
        defer { isResponding = false }

        do {
            let assistantContent = try await chatService.response(for: contextStore.messages)
            appendMessage(assistantContent, role: .assistant, storesInContext: true)
        } catch is CancellationError {
            messages.removeAll { $0.id == userMessage.id }
            contextStore.remove(id: userMessage.id)
        } catch {
            appendMessage(errorMessage(for: error), role: .assistant, storesInContext: false)
        }
    }

    @discardableResult
    func appendMessage(
        _ content: String,
        role: ChatMessage.Role,
        storesInContext: Bool = true
    ) -> ChatMessage? {
        let content = sanitizedContent(from: content)
        guard content.isEmpty == false else { return nil }

        let message = ChatMessage(content: content, role: role)
        messages.append(message)

        if storesInContext {
            contextStore.append(message)
        }

        return message
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
