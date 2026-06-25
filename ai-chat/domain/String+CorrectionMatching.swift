//
//  String+CorrectionMatching.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

extension String {
    var correctionMatchTokens: [String] {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
    }

    var normalizedForCorrectionMatch: String {
        correctionMatchTokens.joined(separator: " ")
    }

    func containsCorrectionPhrase(_ phrase: String) -> Bool {
        let messageTokens = correctionMatchTokens
        let phraseTokens = phrase.correctionMatchTokens

        guard messageTokens.isEmpty == false,
              phraseTokens.isEmpty == false
        else {
            return false
        }

        let normalizedMessage = " \(normalizedForCorrectionMatch) "
        let normalizedPhrase = " \(phrase.normalizedForCorrectionMatch) "

        if normalizedMessage.contains(normalizedPhrase) {
            return true
        }

        var searchIndex = messageTokens.startIndex

        for phraseToken in phraseTokens {
            guard let foundIndex = messageTokens[searchIndex...].firstIndex(of: phraseToken) else {
                return false
            }

            searchIndex = messageTokens.index(after: foundIndex)
        }

        return true
    }
}
