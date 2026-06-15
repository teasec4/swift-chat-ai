//
//  AppDependencies.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import Foundation
import SwiftData

@MainActor
struct AppDependencies {
    let chatStore: any ChatStoring
    let chatService: any ChatServing
    let networkAccessAuthorizer: any NetworkAccessAuthorizing
    let chatConfiguration: ChatFeatureConfiguration
    let modelContainer: ModelContainer

    static func live() throws -> AppDependencies {
        let container = try makeModelContainer(isStoredInMemoryOnly: false)
        let chatConfiguration = ChatFeatureConfiguration.englishPractice
        let serviceConfiguration = DeepSeekChatService.Configuration.live
        return AppDependencies(
            chatStore: SwiftDataChatStore(modelContext: ModelContext(container)),
            chatService: DeepSeekChatService(configuration: serviceConfiguration),
            networkAccessAuthorizer: NetworkAccessAuthorizer(probeURL: serviceConfiguration.availabilityProbeURL),
            chatConfiguration: chatConfiguration,
            modelContainer: container
        )
    }

    static func preview() -> AppDependencies {
        let store = InMemoryChatStore.preview
        let container = try! makeModelContainer(isStoredInMemoryOnly: true)
        let chatConfiguration = ChatFeatureConfiguration.englishPractice

        return AppDependencies(
            chatStore: store,
            chatService: PreviewChatService(),
            networkAccessAuthorizer: PreviewNetworkAccessAuthorizer(),
            chatConfiguration: chatConfiguration,
            modelContainer: container
        )
    }

    private static func makeModelContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema([
            ChatSessionRecord.self,
            ChatMessageRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

private extension InMemoryChatStore {
    static var preview: InMemoryChatStore {
        let session = ChatSession(
            title: "SwiftData chat context",
            createdAt: .now,
            updatedAt: .now
        )

        return InMemoryChatStore(
            sessions: [session],
            messagesBySessionID: [session.id: ChatMessage.previewMessages]
        )
    }
}

private struct PreviewChatService: ChatServing {
    nonisolated func response(for messages: [ChatMessage], systemPrompt: String) async throws -> AssistantResponse {
        AssistantResponse(reply: "Preview response")
    }
}

@MainActor
private final class PreviewNetworkAccessAuthorizer: NetworkAccessAuthorizing {
    var hasUserApproval: Bool {
        true
    }

    func approveNetworkAccess() {}

    func prepareForNetworkUse() async throws {}
}
