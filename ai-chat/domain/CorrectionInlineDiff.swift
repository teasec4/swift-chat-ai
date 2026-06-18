//
//  CorrectionInlineDiff.swift
//  ai-chat
//
//  Created by Codex on 6/18/26.
//

import Foundation

nonisolated struct CorrectionInlineDiffSegment: Hashable, Sendable {
    let text: String
    let style: Style

    nonisolated init(text: String, style: Style) {
        self.text = text
        self.style = style
    }

    nonisolated enum Style: Hashable, Sendable {
        case unchanged
        case removed
        case inserted
    }
}

nonisolated struct CorrectionInlineDiff: Sendable {
    nonisolated static func segments(
        for correction: MessageCorrection,
        sourceText: String?
    ) -> [CorrectionInlineDiffSegment] {
        guard let sourceText = sourceText?.trimmedNonEmpty,
              let range = sourceText.rangeOfCorrectionPhrase(correction.original)
        else {
            return segments(original: correction.original, corrected: correction.corrected)
        }

        let correctedSourceText = sourceText.replacingCharacters(in: range, with: correction.corrected)
        return segments(original: sourceText, corrected: correctedSourceText)
    }

    nonisolated static func segments(
        original: String,
        corrected: String
    ) -> [CorrectionInlineDiffSegment] {
        let originalTokens = original.diffTokens
        let correctedTokens = corrected.diffTokens

        guard originalTokens.isEmpty == false else {
            return makeSegments(
                from: correctedTokens.map { DiffToken(text: $0, style: .inserted) }
            )
        }

        guard correctedTokens.isEmpty == false else {
            return makeSegments(
                from: originalTokens.map { DiffToken(text: $0, style: .removed) }
            )
        }

        return makeSegments(
            from: diffTokens(originalTokens: originalTokens, correctedTokens: correctedTokens)
        )
    }

    private nonisolated static func diffTokens(
        originalTokens: [String],
        correctedTokens: [String]
    ) -> [DiffToken] {
        let originalCount = originalTokens.count
        let correctedCount = correctedTokens.count
        var lengths = Array(
            repeating: Array(repeating: 0, count: correctedCount + 1),
            count: originalCount + 1
        )

        for originalIndex in stride(from: originalCount - 1, through: 0, by: -1) {
            for correctedIndex in stride(from: correctedCount - 1, through: 0, by: -1) {
                if originalTokens[originalIndex] == correctedTokens[correctedIndex] {
                    lengths[originalIndex][correctedIndex] = lengths[originalIndex + 1][correctedIndex + 1] + 1
                } else {
                    lengths[originalIndex][correctedIndex] = max(
                        lengths[originalIndex + 1][correctedIndex],
                        lengths[originalIndex][correctedIndex + 1]
                    )
                }
            }
        }

        var originalIndex = 0
        var correctedIndex = 0
        var diff: [DiffToken] = []

        while originalIndex < originalCount || correctedIndex < correctedCount {
            if originalIndex < originalCount,
               correctedIndex < correctedCount,
               originalTokens[originalIndex] == correctedTokens[correctedIndex] {
                diff.append(DiffToken(text: originalTokens[originalIndex], style: .unchanged))
                originalIndex += 1
                correctedIndex += 1
            } else if correctedIndex < correctedCount,
                      (originalIndex == originalCount
                        || lengths[originalIndex][correctedIndex + 1] > lengths[originalIndex + 1][correctedIndex]) {
                diff.append(DiffToken(text: correctedTokens[correctedIndex], style: .inserted))
                correctedIndex += 1
            } else if originalIndex < originalCount {
                diff.append(DiffToken(text: originalTokens[originalIndex], style: .removed))
                originalIndex += 1
            }
        }

        return diff
    }

    private nonisolated static func makeSegments(
        from tokens: [DiffToken]
    ) -> [CorrectionInlineDiffSegment] {
        tokens.enumerated().reduce(into: []) { segments, element in
            let (index, token) = element
            let text = index == 0 ? token.text : " \(token.text)"

            if let lastSegment = segments.last,
               lastSegment.style == token.style {
                segments[segments.count - 1] = CorrectionInlineDiffSegment(
                    text: lastSegment.text + text,
                    style: token.style
                )
            } else {
                segments.append(CorrectionInlineDiffSegment(text: text, style: token.style))
            }
        }
    }
}

nonisolated private struct DiffToken: Hashable, Sendable {
    let text: String
    let style: CorrectionInlineDiffSegment.Style
}

private extension String {
    nonisolated var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated var diffTokens: [String] {
        split(whereSeparator: \.isWhitespace).map(String.init)
    }

    nonisolated func rangeOfCorrectionPhrase(_ phrase: String) -> Range<String.Index>? {
        guard let phrase = phrase.trimmedNonEmpty else { return nil }

        if let range = firstWordBoundaryRange(of: phrase, options: []) {
            return range
        }

        return firstWordBoundaryRange(of: phrase, options: [.caseInsensitive, .diacriticInsensitive])
    }

    private nonisolated func firstWordBoundaryRange(
        of phrase: String,
        options: String.CompareOptions
    ) -> Range<String.Index>? {
        var searchRange = startIndex..<endIndex

        while let range = range(of: phrase, options: options, range: searchRange) {
            if hasWordBoundaries(around: range, matching: phrase) {
                return range
            }

            guard range.upperBound < endIndex else { break }
            searchRange = range.upperBound..<endIndex
        }

        return nil
    }

    private nonisolated func hasWordBoundaries(
        around range: Range<String.Index>,
        matching phrase: String
    ) -> Bool {
        let needsLeadingBoundary = phrase.first?.isAlphanumeric == true
        let needsTrailingBoundary = phrase.last?.isAlphanumeric == true

        if needsLeadingBoundary,
           range.lowerBound > startIndex,
           self[index(before: range.lowerBound)].isAlphanumeric {
            return false
        }

        if needsTrailingBoundary,
           range.upperBound < endIndex,
           self[range.upperBound].isAlphanumeric {
            return false
        }

        return true
    }
}

private extension Character {
    nonisolated var isAlphanumeric: Bool {
        unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }
}
