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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(corrections.enumerated()), id: \.offset) { index, correction in
                MessageCorrectionCardView(
                    correction: correction,
                    storageKey: "chat.correction.\(messageID.uuidString).\(index).collapsed"
                )
            }
        }
        .frame(maxWidth: 360, alignment: .leading)
    }
}

private struct MessageCorrectionCardView: View {
    let correction: MessageCorrection

    @AppStorage private var isCollapsed: Bool

    init(correction: MessageCorrection, storageKey: String) {
        self.correction = correction
        self._isCollapsed = AppStorage(wrappedValue: false, storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if isCollapsed {
                if let collapsedSummary {
                    Text(collapsedSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                if correction.original.isEmpty == false {
                    CorrectionTextRow(
                        title: "Original",
                        text: correction.original,
                        color: .red,
                        isStrikethrough: true
                    )
                }

                if correction.corrected.isEmpty == false {
                    CorrectionTextRow(
                        title: "Better",
                        text: correction.corrected,
                        color: .green,
                        isStrikethrough: false
                    )
                }

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
}

private struct CorrectionTextRow: View {
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

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
