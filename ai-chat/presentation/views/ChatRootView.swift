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
    @State private var hasPreparedStartupNetwork = false
    @State private var isShowingStartupNetworkPrompt = false
    @State private var startupNetworkErrorMessage: String?

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        TabView {
            HomeTabView(viewModel: viewModel)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            RolePlayTabView(viewModel: viewModel)
            .tabItem {
                Label("Role Play", systemImage: "theatermasks")
            }

            SettingsTabView(viewModel: viewModel)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .task {
            await viewModel.load()
            await prepareNetworkAtStartupIfNeeded()
        }
        .confirmationDialog(
            "Allow Network Access?",
            isPresented: $isShowingStartupNetworkPrompt,
            titleVisibility: .visible
        ) {
            Button("Allow") {
                Task {
                    viewModel.approveNetworkAccess()
                    await prepareNetworkAtStartupIfNeeded(force: true)
                }
            }

            Button("Not Now", role: .cancel) {}
        } message: {
            Text("AI conversations use the network to contact the language model.")
        }
        .alert(
            "Network Unavailable",
            isPresented: isShowingStartupNetworkErrorAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startupNetworkErrorMessage ?? "Network access is unavailable.")
        }
    }

    private var isShowingStartupNetworkErrorAlert: Binding<Bool> {
        Binding {
            startupNetworkErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                startupNetworkErrorMessage = nil
            }
        }
    }

    private func prepareNetworkAtStartupIfNeeded(force: Bool = false) async {
        guard force || hasPreparedStartupNetwork == false else { return }

        if viewModel.hasApprovedNetworkAccess == false {
            isShowingStartupNetworkPrompt = true
            return
        }

        hasPreparedStartupNetwork = true

        do {
            try await viewModel.prepareForNetworkedChat()
        } catch {
            startupNetworkErrorMessage = errorMessage(for: error)
        }
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case let localizedError as LocalizedError:
            localizedError.errorDescription ?? "Network access is unavailable."
        default:
            "Network access is unavailable."
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()

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
