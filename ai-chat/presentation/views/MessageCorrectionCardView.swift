//
//  MessageCorrectionCardView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/14/26.
//

import SwiftUI

struct MessageCorrectionListView: View {
    let messageID: ChatMessage.ID
    let corrections: [MessageCorrection]
    var sourceText: String?
    let feedbackCenter: FeedbackCenter

    @State private var collapseAllCommand = CorrectionCollapseCommand()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if corrections.count > 1 {
                HStack {
                    Spacer(minLength: 0)

                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            collapseAllCommand = CorrectionCollapseCommand()
                        }
                    } label: {
                        Label("Collapse all", systemImage: "rectangle.compress.vertical")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Collapse all corrections")
                }
            }

            ForEach(Array(corrections.enumerated()), id: \.offset) { index, correction in
                MessageCorrectionCardView(
                    messageID: messageID,
                    correction: correction,
                    sourceText: sourceText,
                    collapseAllCommand: collapseAllCommand,
                    storageKey: "chat.correction.\(messageID.uuidString).\(index).collapsed",
                    feedbackCenter: feedbackCenter
                )
            }
        }
        .frame(maxWidth: 360, alignment: .leading)
    }
}

private struct MessageCorrectionCardView: View {
    let messageID: ChatMessage.ID
    let correction: MessageCorrection
    let sourceText: String?
    let collapseAllCommand: CorrectionCollapseCommand
    let feedbackCenter: FeedbackCenter

    @AppStorage private var isCollapsed: Bool

    init(
        messageID: ChatMessage.ID,
        correction: MessageCorrection,
        sourceText: String?,
        collapseAllCommand: CorrectionCollapseCommand,
        storageKey: String,
        feedbackCenter: FeedbackCenter
    ) {
        self.messageID = messageID
        self.correction = correction
        self.sourceText = sourceText
        self.collapseAllCommand = collapseAllCommand
        self.feedbackCenter = feedbackCenter
        self._isCollapsed = AppStorage(wrappedValue: false, storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)

                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) correction")
                .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")

                Button {
                    feedbackCenter.save(correction: correction, sourceMessageID: messageID)
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSaved ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(isSaved)
                .accessibilityLabel(isSaved ? "Correction saved" : "Save correction")
            }

            if isCollapsed {
                if let collapsedSummary {
                    Text(collapsedSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                CorrectionTextRowsView(correction: correction, sourceText: sourceText)

                if let explanation = correction.explanation {
                    Text(explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .onChange(of: collapseAllCommand) { _, _ in
            isCollapsed = true
        }
    }

    private var title: String {
        guard let type = correction.type else { return "Correction" }

        return type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var collapsedSummary: String? {
        switch (correction.original.trimmedNonEmpty, correction.corrected.trimmedNonEmpty) {
        case let (.some(original), .some(corrected)):
            "\(original) -> \(corrected)"
        case let (.some(original), .none):
            original
        case let (.none, .some(corrected)):
            corrected
        case (.none, .none):
            correction.explanation?.trimmedNonEmpty
        }
    }

    private var isSaved: Bool {
        feedbackCenter.contains(correction: correction, sourceMessageID: messageID)
    }
}

private struct CorrectionCollapseCommand: Equatable {
    private let id = UUID()
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
