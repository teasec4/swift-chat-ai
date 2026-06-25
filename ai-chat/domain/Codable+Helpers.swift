//
//  Codable+Helpers.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation

extension KeyedDecodingContainer {
    func decodeFirstTrimmedString(for keys: [Key]) -> String? {
        for key in keys {
            do {
                guard let value = try decodeIfPresent(String.self, forKey: key),
                      let trimmedValue = value.trimmedNonEmpty
                else {
                    continue
                }

                return trimmedValue
            } catch {
                continue
            }
        }

        return nil
    }
}
