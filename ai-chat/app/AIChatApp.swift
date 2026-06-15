//
//  AIChatApp.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/11/26.
//

import SwiftUI
import SwiftData

@main
@MainActor
struct AIChatApp: App {
    @State private var dependencies: AppDependencies
    @State private var feedbackCenter: FeedbackCenter

    init() {
        do {
            let dependencies = try AppDependencies.live()
            _dependencies = State(initialValue: dependencies)
            _feedbackCenter = State(initialValue: FeedbackCenter(store: dependencies.feedbackStore))
        } catch {
            fatalError("Failed to create app dependencies: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ChatRootView(
                viewModel: ChatViewModel(
                    chatStore: dependencies.chatStore,
                    chatService: dependencies.chatService,
                    networkAccessAuthorizer: dependencies.networkAccessAuthorizer,
                    configuration: dependencies.chatConfiguration
                ),
                feedbackCenter: feedbackCenter
            )
            .modelContainer(dependencies.modelContainer)
        }
    }
}
