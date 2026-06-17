//
//  HomeTabView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/14/26.
//

import SwiftUI

struct HomeTabView: View {
    let viewModel: ChatViewModel
    let feedbackCenter: FeedbackCenter

    @State private var path: [ChatSession.ID] = []
    @State private var pendingNetworkTopic: LanguageTopic?
    @State private var networkErrorMessage: String?
    @State private var isPreparingNetworkAccess = false

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.topics) { topic in
                        Button {
                            handleTopicTap(topic)
                        } label: {
                            LanguageTopicCardView(topic: topic)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPreparingNetworkAccess)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isPreparingNetworkAccess {
                    PreparingNetworkAccessView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .navigationDestination(for: ChatSession.ID.self) { sessionID in
                ChatSessionDestinationView(
                    viewModel: viewModel,
                    sessionID: sessionID,
                    feedbackCenter: feedbackCenter,
                    onFreshSessionCreated: { freshSessionID in
                        path = [freshSessionID]
                    }
                )
            }
        }
        .confirmationDialog(
            "Allow Network Access?",
            isPresented: isShowingNetworkApprovalDialog,
            titleVisibility: .visible,
            presenting: pendingNetworkTopic
        ) { topic in
            Button("Allow and Continue") {
                viewModel.approveNetworkAccess()
                openSession(with: topic)
            }

            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("AI conversations use the network to contact the language model.")
        }
        .alert(
            "Network Unavailable",
            isPresented: isShowingNetworkErrorAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(networkErrorMessage ?? "Network access is unavailable.")
        }
    }

    private var isShowingNetworkApprovalDialog: Binding<Bool> {
        Binding {
            pendingNetworkTopic != nil
        } set: { isPresented in
            if isPresented == false {
                pendingNetworkTopic = nil
            }
        }
    }

    private var isShowingNetworkErrorAlert: Binding<Bool> {
        Binding {
            networkErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                networkErrorMessage = nil
            }
        }
    }

    private func handleTopicTap(_ topic: LanguageTopic) {
        guard viewModel.hasApprovedNetworkAccess else {
            pendingNetworkTopic = topic
            return
        }

        openSession(with: topic)
    }

    private func openSession(with topic: LanguageTopic) {
        guard isPreparingNetworkAccess == false else { return }

        Task {
            isPreparingNetworkAccess = true
            defer { isPreparingNetworkAccess = false }

            do {
                try await viewModel.prepareForNetworkedChat()

                if let sessionID = await viewModel.openSession(for: topic) {
                    path = [sessionID]
                    await viewModel.startConversation(in: sessionID)
                }
            } catch {
                networkErrorMessage = errorMessage(for: error)
            }
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

private struct LanguageTopicCardView: View {
    let topic: LanguageTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: topic.iconName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(topic.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PreparingNetworkAccessView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Preparing network access...")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}
