//
//  ProgressTabView.swift
//  ai-chat
//
//  Created by Codex on 6/16/26.
//

import SwiftUI

struct ProgressTabView: View {
    let feedbackCenter: FeedbackCenter

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FeedbackCorrectionCategory.allCases) { category in
                        NavigationLink {
                            FeedbackCategoryDetailView(
                                category: category,
                                feedbackCenter: feedbackCenter
                            )
                        } label: {
                            FeedbackCategoryRow(
                                category: category,
                                savedCount: feedbackCenter.items(in: category).count
                            )
                        }
                    }
                } header: {
                    Text("Feedback Center")
                }
            }
            .navigationTitle("Progress")
        }
    }
}

private struct FeedbackCategoryDetailView: View {
    let category: FeedbackCorrectionCategory
    let feedbackCenter: FeedbackCenter

    var body: some View {
        List {
            if items.isEmpty {
                EmptyFeedbackCategoryRow()
            } else {
                ForEach(items) { item in
                    FeedbackItemRow(item: item)
                        .swipeActions {
                            Button(role: .destructive) {
                                feedbackCenter.delete(itemID: item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(category.title)
    }

    private var items: [FeedbackItem] {
        feedbackCenter.items(in: category)
    }
}

private struct FeedbackCategoryRow: View {
    let category: FeedbackCorrectionCategory
    let savedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if savedCount > 0 {
                Text(savedCount.formatted())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .background(
                        Color(.tertiarySystemGroupedBackground),
                        in: Capsule()
                    )
            }
        }
        .padding(.vertical, 3)
    }
}

private struct FeedbackItemRow: View {
    let item: FeedbackItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.correction.original.isEmpty == false {
                FeedbackTextRow(
                    title: "Original",
                    text: item.correction.original,
                    color: .red,
                    isStrikethrough: true
                )
            }

            if item.correction.corrected.isEmpty == false {
                FeedbackTextRow(
                    title: "Better",
                    text: item.correction.corrected,
                    color: .green,
                    isStrikethrough: false
                )
            }

            if let explanation = item.correction.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(item.createdAt.formatted(Self.createdAtFormat))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private static let createdAtFormat = Date.FormatStyle(
        date: .abbreviated,
        time: .shortened,
        locale: Locale(identifier: "en_US")
    )
}

private struct FeedbackTextRow: View {
    let title: String
    let text: String
    let color: Color
    let isStrikethrough: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(color)
                .strikethrough(isStrikethrough, color: color)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EmptyFeedbackCategoryRow: View {
    var body: some View {
        Text("No saved corrections yet.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }
}
