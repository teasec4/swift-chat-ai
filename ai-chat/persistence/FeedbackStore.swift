//
//  FeedbackStore.swift
//  ai-chat
//
//  Created by Codex on 6/16/26.
//

import Foundation
import Observation

@MainActor
protocol FeedbackStoring: AnyObject {
    func fetchItems() -> [FeedbackItem]
    func saveItems(_ items: [FeedbackItem])
}

@MainActor
final class UserDefaultsFeedbackStore: FeedbackStoring {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "savedFeedbackItems"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func fetchItems() -> [FeedbackItem] {
        guard let data = defaults.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([FeedbackItem].self, from: data)
        else {
            return []
        }

        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func saveItems(_ items: [FeedbackItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

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
        store.saveItems(items)
    }

    func delete(itemID: FeedbackItem.ID) {
        items.removeAll { $0.id == itemID }
        store.saveItems(items)
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
