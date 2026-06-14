//
//  ChatTranscriptView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let isResponding: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                    }

                    if isResponding {
                        AssistantLoadingBubbleView()
                            .id(Self.loadingBubbleID)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scheduleScrollToBottom(with: proxy, animated: false)
            }
            .onChange(of: messages.last?.id) { _, _ in
                scheduleScrollToBottom(with: proxy)
            }
            .onChange(of: messages.count) { _, _ in
                scheduleScrollToBottom(with: proxy)
            }
            .onChange(of: isResponding) { _, _ in
                scheduleScrollToBottom(with: proxy)
            }
        }
    }

    private static let loadingBubbleID = "assistant-loading-bubble"

    private func scheduleScrollToBottom(
        with proxy: ScrollViewProxy,
        animated: Bool = true
    ) {
        Task { @MainActor in
            await Task.yield()
            scrollToBottom(with: proxy, animated: animated)
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        let targetID: AnyHashable

        if isResponding {
            targetID = Self.loadingBubbleID
        } else if let lastMessageID = messages.last?.id {
            targetID = lastMessageID
        } else {
            return
        }

        if animated {
            withAnimation(.snappy) {
                proxy.scrollTo(targetID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(targetID, anchor: .bottom)
        }
    }
}

private struct AssistantLoadingBubbleView: View {
    var body: some View {
        HStack(alignment: .bottom) {
            ProgressView()
                .controlSize(.small)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .accessibilityLabel("Assistant is responding")

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
    }
}
