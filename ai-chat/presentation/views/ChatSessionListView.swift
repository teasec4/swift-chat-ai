//
//  ChatSessionListView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI

struct ChatSessionListView: View {
    let viewModel: ChatViewModel
    let onCreateSession: () -> Void

    init(
        viewModel: ChatViewModel,
        onCreateSession: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onCreateSession = onCreateSession
    }

    var body: some View {
        List {
            ForEach(viewModel.sessions) { session in
                NavigationLink(value: session.id) {
                    ChatSessionRow(
                        session: session,
                        isSelected: session.id == viewModel.selectedSessionID
                    )
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteSession(session.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Session History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCreateSession) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New Session")
            }
        }
    }
}

struct ChatSessionDestinationView: View {
    let viewModel: ChatViewModel
    let sessionID: ChatSession.ID

    var body: some View {
        ChatConversationView(viewModel: viewModel)
            .task(id: sessionID) {
                await viewModel.selectSession(sessionID)
            }
    }
}

private struct ChatSessionRow: View {
    let session: ChatSession
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(session.updatedAt.formatted(Self.updatedAtFormat))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let topicTitle = session.topicTitle {
                Text(topicTitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private static let updatedAtFormat = Date.FormatStyle(
        date: .abbreviated,
        time: .shortened,
        locale: Locale(identifier: "en_US")
    )
}
