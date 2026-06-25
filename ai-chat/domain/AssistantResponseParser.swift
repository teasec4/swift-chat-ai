//
//  AssistantResponseParser.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/15/26.
//

import Foundation

struct AssistantResponseParser: Sendable {
    nonisolated static let standard = AssistantResponseParser()

    nonisolated func response(from modelContent: String) -> AssistantResponse? {
        guard let content = modelContent.trimmedNonEmpty else { return nil }

        if let structuredResponse = structuredResponse(from: content) {
            return structuredResponse
        }

        guard content.looksLikeJSONContainer == false else { return nil }

        return AssistantResponse(reply: content)
    }

    nonisolated func structuredResponse(from modelContent: String) -> AssistantResponse? {
        guard let content = modelContent.trimmedNonEmpty else { return nil }
        return decodeStructuredResponse(from: content)
    }

    private nonisolated func decodeStructuredResponse(from content: String) -> AssistantResponse? {
        let decoder = JSONDecoder()

        for candidate in content.jsonCandidates {
            guard let data = candidate.data(using: .utf8),
                  let response = try? decoder.decode(AssistantResponse.self, from: data),
                  response.reply.isEmpty == false
            else {
                continue
            }

            return response
        }

        return nil
    }
}

extension AssistantResponse {
    nonisolated static func make(from modelContent: String) -> AssistantResponse? {
        AssistantResponseParser.standard.response(from: modelContent)
    }
}

private extension String {

    nonisolated var jsonCandidates: [String] {
        [
            trimmedNonEmpty,
            removingMarkdownFence,
            firstJSONObject
        ]
        .compactMap { $0 }
        .deduplicated
    }

    nonisolated var removingMarkdownFence: String? {
        guard let trimmed = trimmedNonEmpty, trimmed.hasPrefix("```") else { return nil }

        var lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.isEmpty == false else { return nil }

        lines.removeFirst()

        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
            lines.removeLast()
        }

        return lines.joined(separator: "\n").trimmedNonEmpty
    }

    nonisolated var firstJSONObject: String? {
        guard let startIndex = firstIndex(of: "{"),
              let endIndex = lastIndex(of: "}"),
              startIndex <= endIndex
        else {
            return nil
        }

        return String(self[startIndex...endIndex]).trimmedNonEmpty
    }

    nonisolated var looksLikeJSONContainer: Bool {
        guard let trimmed = trimmedNonEmpty else { return false }

        return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }
}

private extension Array where Element: Equatable {
    nonisolated var deduplicated: [Element] {
        reduce(into: []) { result, element in
            guard result.contains(element) == false else { return }
            result.append(element)
        }
    }
}
