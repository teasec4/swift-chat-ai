//
//  SettingsTabView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/14/26.
//

import SwiftUI

struct SettingsTabView: View {
    let viewModel: ChatViewModel
    let feedbackCenter: FeedbackCenter

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: SettingsRoute.sessionHistory) {
                        Label("Session History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .sessionHistory:
                    ChatSessionListView(
                        viewModel: viewModel,
                        onCreateSession: createSession
                    )
                }
            }
            .navigationDestination(for: ChatSession.ID.self) { sessionID in
                ChatSessionDestinationView(
                    viewModel: viewModel,
                    sessionID: sessionID,
                    feedbackCenter: feedbackCenter,
                    onFreshSessionCreated: navigateToSessionInHistory
                )
            }
        }
    }

    private func createSession() {
        Task {
            if let sessionID = await viewModel.createSession() {
                navigateToSessionInHistory(sessionID)
            }
        }
    }

    private func navigateToSessionInHistory(_ sessionID: ChatSession.ID) {
        var newPath = NavigationPath()
        newPath.append(SettingsRoute.sessionHistory)
        newPath.append(sessionID)
        path = newPath
    }
}

private enum SettingsRoute: Hashable {
    case sessionHistory
}
