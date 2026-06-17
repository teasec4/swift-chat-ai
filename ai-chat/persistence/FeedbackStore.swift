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
    func saveItem(_ item: FeedbackItem)
    func deleteItem(id: FeedbackItem.ID)
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

    func saveItem(_ item: FeedbackItem) {
        if let record = record(id: item.id) {
            record.update(from: item)
        } else {
            modelContext.insert(FeedbackItemRecord(item: item))
        }

        try? modelContext.save()
    }

    func deleteItem(id: FeedbackItem.ID) {
        guard let record = record(id: id) else { return }

        modelContext.delete(record)
        try? modelContext.save()
    }

    private func record(id: FeedbackItem.ID) -> FeedbackItemRecord? {
        var descriptor = FetchDescriptor<FeedbackItemRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
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
