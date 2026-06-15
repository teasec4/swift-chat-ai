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

    nonisolated func partialReply(from modelContent: String) -> String? {
        guard let content = modelContent.trimmedNonEmpty else { return nil }

        if let structuredResponse = structuredResponse(from: content) {
            return structuredResponse.reply.trimmedNonEmpty
        }

        for candidate in content.partialJSONCandidates {
            for key in AssistantResponse.replyCodingKeyNames {
                if let value = candidate.jsonStringValuePrefix(forKey: key)?.trimmedNonEmpty {
                    return value
                }
            }
        }

        return nil
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

    nonisolated static let replyCodingKeyNames = [
        "reply",
        "message",
        "response",
        "answer"
    ]
}

private extension String {
    nonisolated var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated var jsonCandidates: [String] {
        [
            trimmedNonEmpty,
            removingMarkdownFence,
            firstJSONObject
        ]
        .compactMap { $0 }
        .deduplicated
    }

    nonisolated var partialJSONCandidates: [String] {
        [
            trimmedNonEmpty,
            removingMarkdownFence
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

    nonisolated func jsonStringValuePrefix(forKey key: String) -> String? {
        let characters = Array(self)
        var index = 0

        while index < characters.count {
            guard characters[index] == "\"" else {
                index += 1
                continue
            }

            let keyStartIndex = index
            guard let parsedKey = parseJSONString(in: characters, startingAt: index),
                  parsedKey.value == key
            else {
                index += 1
                continue
            }

            index = parsedKey.endIndex
            skipWhitespace(in: characters, index: &index)
            guard index < characters.count, characters[index] == ":" else {
                index = keyStartIndex + 1
                continue
            }

            index += 1
            skipWhitespace(in: characters, index: &index)
            guard index < characters.count, characters[index] == "\"" else {
                return nil
            }

            return parseJSONStringPrefix(in: characters, startingAt: index)
        }

        return nil
    }

    nonisolated func parseJSONString(
        in characters: [Character],
        startingAt startIndex: Int
    ) -> (value: String, endIndex: Int)? {
        var index = startIndex
        guard index < characters.count, characters[index] == "\"" else { return nil }

        index += 1
        var value = ""

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                return (value, index + 1)
            }

            if character == "\\" {
                index += 1
                guard index < characters.count else { return nil }
                value.append(decodedEscapedCharacter(characters[index]))
                index += 1
                continue
            }

            value.append(character)
            index += 1
        }

        return nil
    }

    nonisolated func parseJSONStringPrefix(
        in characters: [Character],
        startingAt startIndex: Int
    ) -> String? {
        var index = startIndex
        guard index < characters.count, characters[index] == "\"" else { return nil }

        index += 1
        var value = ""

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                return value
            }

            if character == "\\" {
                index += 1
                guard index < characters.count else { return value }
                value.append(decodedEscapedCharacter(characters[index]))
                index += 1
                continue
            }

            value.append(character)
            index += 1
        }

        return value
    }

    nonisolated func skipWhitespace(in characters: [Character], index: inout Int) {
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
    }

    nonisolated func decodedEscapedCharacter(_ character: Character) -> Character {
        switch character {
        case "\"":
            "\""
        case "\\":
            "\\"
        case "/":
            "/"
        case "b":
            "\u{08}"
        case "f":
            "\u{0C}"
        case "n":
            "\n"
        case "r":
            "\r"
        case "t":
            "\t"
        default:
            character
        }
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
