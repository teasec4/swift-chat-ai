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
    @State private var feedbackCenter: FeedbackCenter

    init(viewModel: ChatViewModel, feedbackCenter: FeedbackCenter) {
        _viewModel = State(initialValue: viewModel)
        _feedbackCenter = State(initialValue: feedbackCenter)
    }

    var body: some View {
        TabView {
            HomeTabView(viewModel: viewModel, feedbackCenter: feedbackCenter)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            RolePlayTabView(viewModel: viewModel, feedbackCenter: feedbackCenter)
            .tabItem {
                Label("Role Play", systemImage: "theatermasks")
            }

            ProgressTabView(feedbackCenter: feedbackCenter)
            .tabItem {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
            }

            SettingsTabView(viewModel: viewModel, feedbackCenter: feedbackCenter)
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
            configuration: dependencies.chatConfiguration
        ),
        feedbackCenter: FeedbackCenter(store: dependencies.feedbackStore)
    )
    .modelContainer(dependencies.modelContainer)
}
