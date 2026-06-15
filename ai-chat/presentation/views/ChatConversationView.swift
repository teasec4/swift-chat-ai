//
//  ChatConversationView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI

struct ChatConversationView: View {
    let viewModel: ChatViewModel
    let feedbackCenter: FeedbackCenter

    @State private var draft = ""
    @State private var topicPendingFreshSession: LanguageTopic?
    @State private var rolePlayScenarioPendingFreshSession: RolePlayScenario?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if viewModel.selectedSession == nil {
                ContentUnavailableView("No Chat", systemImage: "bubble.left.and.bubble.right")
            } else {
                ChatTranscriptView(
                    messages: viewModel.messages,
                    isResponding: viewModel.isSelectedSessionResponding,
                    partialResponse: viewModel.selectedPartialResponse,
                    feedbackCenter: feedbackCenter
                )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        VStack(spacing: 0) {
                            if let errorNotice = viewModel.selectedSessionError {
                                ChatErrorBanner(
                                    notice: errorNotice,
                                    onRetry: retryFailedRequest,
                                    onDismiss: viewModel.dismissErrorForSelectedSession
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            }

                            MessageInputBar(
                                text: $draft,
                                isSending: viewModel.isSelectedSessionResponding,
                                canSend: viewModel.canSend(draft),
                                focus: $isInputFocused,
                                onSend: sendMessage,
                                onCancel: cancelResponse
                            )
                        }
                    }
            }
        }
        .navigationTitle(viewModel.selectedSession?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            if let currentTopic {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        topicPendingFreshSession = currentTopic
                    } label: {
                        Image(systemName: "plus.message")
                    }
                    .accessibilityLabel("Start Fresh Session")
                }
            } else if let currentRolePlayScenario {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        rolePlayScenarioPendingFreshSession = currentRolePlayScenario
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
        .confirmationDialog(
            "Start a New Session?",
            isPresented: isShowingFreshRolePlaySessionConfirmation,
            titleVisibility: .visible,
            presenting: rolePlayScenarioPendingFreshSession
        ) { scenario in
            Button("Start Fresh Session") {
                startFreshSession(with: scenario)
            }

            Button("Cancel", role: .cancel) {}
        } message: { scenario in
            Text("Your current \(scenario.title) role play will stay in Session History.")
        }
        .onChange(of: viewModel.selectedSessionID) { _, _ in
            draft = ""
        }
    }

    private var currentTopic: LanguageTopic? {
        viewModel.topic(for: viewModel.selectedSession)
    }

    private var currentRolePlayScenario: RolePlayScenario? {
        viewModel.rolePlayScenario(for: viewModel.selectedSession)
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

    private var isShowingFreshRolePlaySessionConfirmation: Binding<Bool> {
        Binding {
            rolePlayScenarioPendingFreshSession != nil
        } set: { isPresented in
            if isPresented == false {
                rolePlayScenarioPendingFreshSession = nil
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

    private func cancelResponse() {
        viewModel.cancelResponseForSelectedSession()
        isInputFocused = true
    }

    private func retryFailedRequest() {
        Task {
            await viewModel.retryFailedRequestForSelectedSession()
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

    private func startFreshSession(with scenario: RolePlayScenario) {
        rolePlayScenarioPendingFreshSession = nil
        draft = ""

        Task {
            if let sessionID = await viewModel.createSession(rolePlayScenario: scenario) {
                await viewModel.startConversation(in: sessionID)
            }
        }
    }
}

private struct ChatErrorBanner: View {
    let notice: ChatErrorNotice
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(notice.message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if notice.canRetry {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .accessibilityLabel("Retry")
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .accessibilityLabel("Dismiss")
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
        .accessibilityElement(children: .combine)
    }
}
