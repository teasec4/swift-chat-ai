//
//  CorrectionTextRowsView.swift
//  ai-chat
//
//  Created by Codex on 6/18/26.
//

import SwiftUI

struct CorrectionTextRowsView: View {
    let correction: MessageCorrection
    var sourceText: String? = nil

    var body: some View {
        if correction.original.isEmpty == false,
           correction.corrected.isEmpty == false {
            CorrectionInlineDiffRow(
                title: "Fix",
                segments: CorrectionInlineDiff.segments(
                    for: correction,
                    sourceText: sourceText
                )
            )
        } else {
            if correction.original.isEmpty == false {
                CorrectionPlainTextRow(
                    title: "Original",
                    text: correction.original,
                    color: .red,
                    isStrikethrough: true
                )
            }

            if correction.corrected.isEmpty == false {
                CorrectionPlainTextRow(
                    title: "Better",
                    text: correction.corrected,
                    color: .green,
                    isStrikethrough: false
                )
            }
        }
    }
}

private struct CorrectionInlineDiffRow: View {
    let title: String
    let segments: [CorrectionInlineDiffSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(inlineText)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inlineText: AttributedString {
        segments.reduce(into: AttributedString()) { attributedText, segment in
            var segmentText = AttributedString(segment.text)
            segmentText.foregroundColor = color(for: segment.style)

            if segment.style == .removed {
                segmentText.strikethroughStyle = .single
                segmentText.strikethroughColor = .red
            }

            attributedText += segmentText
        }
    }

    private func color(for style: CorrectionInlineDiffSegment.Style) -> Color {
        switch style {
        case .unchanged:
            .primary
        case .removed:
            .red
        case .inserted:
            .green
        }
    }
}

private struct CorrectionPlainTextRow: View {
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
