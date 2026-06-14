//
//  ChatConversationView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI

struct ChatConversationView: View {
    let viewModel: ChatViewModel

    @State private var draft = ""
    @State private var topicPendingFreshSession: LanguageTopic?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if viewModel.selectedSession == nil {
                ContentUnavailableView("No Chat", systemImage: "bubble.left.and.bubble.right")
            } else {
                ChatTranscriptView(
                    messages: viewModel.messages,
                    isResponding: viewModel.isResponding
                )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        MessageInputBar(
                            text: $draft,
                            isSending: viewModel.isResponding,
                            canSend: viewModel.canSend(draft),
                            focus: $isInputFocused,
                            onSend: sendMessage
                        )
                    }
            }
        }
        .navigationTitle(viewModel.selectedSession?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if currentTopic != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        topicPendingFreshSession = currentTopic
                    } label: {
                        Image(systemName: "plus.message")
                    }
                    .accessibilityLabel("Start Fresh Session")
                }
            }
        }
        .confirmationDialog(
            "Start a New Session?",
            isPresented: isShowingFreshSessionConfirmation,
            titleVisibility: .visible,
            presenting: topicPendingFreshSession
        ) { topic in
            Button("Start Fresh Session") {
                startFreshSession(with: topic)
            }

            Button("Cancel", role: .cancel) {}
        } message: { topic in
            Text("Your current \(topic.title) session will stay in Session History.")
        }
        .onChange(of: viewModel.selectedSessionID) { _, _ in
            draft = ""
        }
    }

    private var currentTopic: LanguageTopic? {
        guard let topicID = viewModel.selectedSession?.topicID else { return nil }
        return LanguageTopic.all.first { $0.id == topicID }
    }

    private var isShowingFreshSessionConfirmation: Binding<Bool> {
        Binding {
            topicPendingFreshSession != nil
        } set: { isPresented in
            if isPresented == false {
                topicPendingFreshSession = nil
            }
        }
    }

    private func sendMessage() {
        let content = draft
        guard viewModel.canSend(content) else { return }

        draft = ""

        Task {
            await viewModel.sendMessage(content)
            isInputFocused = true
        }
    }

    private func startFreshSession(with topic: LanguageTopic) {
        topicPendingFreshSession = nil
        draft = ""

        Task {
            if let sessionID = await viewModel.createSession(topic: topic) {
                await viewModel.startConversation(in: sessionID)
            }
        }
    }
}
