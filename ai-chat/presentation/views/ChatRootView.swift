//
//  ChatRootView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI
import SwiftData

@MainActor
struct ChatRootView: View {
    @State private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        TabView {
            HomeTabView(viewModel: viewModel)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            SettingsTabView(viewModel: viewModel)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()

    ChatRootView(
        viewModel: ChatViewModel(
            chatStore: dependencies.chatStore,
            chatService: dependencies.chatService,
            networkAccessAuthorizer: dependencies.networkAccessAuthorizer
        )
    )
    .modelContainer(dependencies.modelContainer)
}
