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

    init() {
        do {
            _dependencies = State(initialValue: try AppDependencies.live())
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
                )
            )
            .modelContainer(dependencies.modelContainer)
        }
    }
}
