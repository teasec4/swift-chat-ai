//
//  FeedbackStore.swift
//  ai-chat
//
//  Created by Codex on 6/16/26.
//

import Foundation
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
