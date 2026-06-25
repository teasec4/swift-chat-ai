//
//  String+TrimmedNonEmpty.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
