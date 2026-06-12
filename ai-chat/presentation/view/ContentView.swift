//
//  ContentView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/11/26.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @State private var viewModel: ChatViewModel
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    init() {
        _viewModel = State(initialValue: ChatViewModel())
    }

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        chatTranscript
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MessageInputBar(
                    text: $draft,
                    isSending: viewModel.isResponding,
                    canSend: viewModel.canSend(draft),
                    focus: $isInputFocused,
                    onSend: sendMessage
                )
            }
            .background(Color(.systemGroupedBackground))
    }

    private var chatTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToBottom(with: proxy, animated: false)
            }
            .onChange(of: viewModel.messages.last?.id) { _, _ in
                scrollToBottom(with: proxy)
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

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessageID = viewModel.messages.last?.id else { return }

        if animated {
            withAnimation(.snappy) {
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }
}


struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user {
                Spacer(minLength: 48)
            }

            Text(message.content)
                .font(.body)
                .foregroundStyle(foregroundStyle)
                .textSelection(.enabled)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel(accessibilityLabel)

            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var backgroundStyle: Color {
        message.role == .user ? .accentColor : Color(.secondarySystemGroupedBackground)
    }

    private var foregroundStyle: Color {
        message.role == .user ? .white : .primary
    }

    private var accessibilityLabel: String {
        switch message.role {
        case .user:
            "You: \(message.content)"
        case .assistant:
            "Assistant: \(message.content)"
        }
    }
}

private struct MessageInputBar: View {
    @Binding var text: String

    let isSending: Bool
    let canSend: Bool
    let focus: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .focused(focus)
                .lineLimit(1...5)
                .submitLabel(.send)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
                .onSubmit {
                    guard canSend else { return }
                    onSend()
                }
                .accessibilityIdentifier("messageInput")

            Button(action: onSend) {
                ZStack {
                    Image(systemName: "paperplane.fill")
                        .opacity(isSending ? 0 : 1)

                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .disabled(canSend == false || isSending)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("sendButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}


#Preview {
    ContentView(
        viewModel: ChatViewModel(
            messages: ChatMessage.previewMessages,
            chatService: PreviewChatService()
        )
    )
}

private struct PreviewChatService: ChatServing {
    nonisolated func response(for messages: [ChatMessage]) async throws -> String {
        "Preview response"
    }
}
