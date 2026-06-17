//
//  FeedbackStore.swift
//  ai-chat
//
//  Created by Codex on 6/16/26.
//

import Foundation
import Observation
import SwiftData

@MainActor
protocol FeedbackStoring: AnyObject {
    func fetchItems() -> [FeedbackItem]
    func saveItems(_ items: [FeedbackItem])
}

@MainActor
final class SwiftDataFeedbackStore: FeedbackStoring {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchItems() -> [FeedbackItem] {
        let descriptor = FetchDescriptor<FeedbackItemRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return ((try? modelContext.fetch(descriptor)) ?? [])
            .map(FeedbackItem.init(record:))
    }

    func saveItems(_ items: [FeedbackItem]) {
        let existingRecords = fetchRecords()
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for record in existingRecords where itemsByID[record.id] == nil {
            modelContext.delete(record)
        }

        for item in items {
            if let record = existingRecords.first(where: { $0.id == item.id }) {
                record.update(from: item)
            } else {
                modelContext.insert(
                    FeedbackItemRecord(
                        id: item.id,
                        correction: item.correction,
                        sourceMessageID: item.sourceMessageID,
                        createdAt: item.createdAt
                    )
                )
            }
        }

        try? modelContext.save()
    }

    private func fetchRecords() -> [FeedbackItemRecord] {
        let descriptor = FetchDescriptor<FeedbackItemRecord>()
        return (try? modelContext.fetch(descriptor)) ?? []
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
