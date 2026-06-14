//
//  MessageCorrectionCardView.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/14/26.
//

import SwiftUI

struct MessageCorrectionListView: View {
    let corrections: [MessageCorrection]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(corrections.enumerated()), id: \.offset) { _, correction in
                MessageCorrectionCardView(correction: correction)
            }
        }
        .frame(maxWidth: 360, alignment: .leading)
    }
}

private struct MessageCorrectionCardView: View {
    let correction: MessageCorrection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

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
        .padding(10)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard let type = correction.type else { return "Correction" }

        return type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
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
