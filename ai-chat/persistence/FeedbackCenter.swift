//
//  FeedbackCenter.swift
//  ai-chat
//
//  Created by Codex on 6/25/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class FeedbackCenter {
    private(set) var items: [FeedbackItem] = []

    @ObservationIgnored private let store: any FeedbackStoring

    init(store: any FeedbackStoring) {
        self.store = store
        items = store.fetchItems()
    }

    func save(correction: MessageCorrection, sourceMessageID: ChatMessage.ID? = nil) {
        let item = FeedbackItem(correction: correction, sourceMessageID: sourceMessageID)
        guard contains(item) == false else { return }

        items.insert(item, at: 0)
        store.saveItem(item)
    }

    func delete(itemID: FeedbackItem.ID) {
        items.removeAll { $0.id == itemID }
        store.deleteItem(id: itemID)
    }

    func contains(correction: MessageCorrection, sourceMessageID: ChatMessage.ID? = nil) -> Bool {
        items.contains {
            $0.sourceMessageID == sourceMessageID && $0.correction == correction
        }
    }

    func items(in category: FeedbackCorrectionCategory) -> [FeedbackItem] {
        items.filter { $0.category == category }
    }

    private func contains(_ item: FeedbackItem) -> Bool {
        items.contains {
            $0.sourceMessageID == item.sourceMessageID && $0.correction == item.correction
        }
    }
}
