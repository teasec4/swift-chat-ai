//
//  ChatBubbleView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI

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
