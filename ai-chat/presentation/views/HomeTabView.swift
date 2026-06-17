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
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
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
    }

    private func handleTopicTap(_ topic: LanguageTopic) {
        openSession(with: topic)
    }

    private func openSession(with topic: LanguageTopic) {
        Task {
            if let sessionID = await viewModel.openSession(for: topic) {
                path = [sessionID]
                await viewModel.startConversation(in: sessionID)
            }
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
