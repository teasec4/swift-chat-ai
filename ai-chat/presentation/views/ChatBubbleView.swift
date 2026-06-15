//
//  ChatBubbleView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let feedbackCenter: FeedbackCenter

    var body: some View {
        switch message.role {
        case .user:
            userMessageView
        case .assistant:
            assistantMessageView
        }
    }

    private var userMessageView: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 48)

            messageTextBubble

        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                messageTextBubble

                Spacer(minLength: 48)
            }

            if message.corrections.isEmpty == false {
                MessageCorrectionListView(
                    messageID: message.id,
                    corrections: message.corrections,
                    feedbackCenter: feedbackCenter
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageTextBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundStyle(foregroundStyle)
            .textSelection(.enabled)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel(accessibilityLabel)
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
