import Foundation
import SwiftData

@MainActor
final class CacheRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func replaceResumePoints(_ points: [ResumePoint]) throws {
        let descriptor = FetchDescriptor<CachedResumePoint>()
        let existing = try context.fetch(descriptor)
        existing.forEach { context.delete($0) }
        points.forEach { context.insert(CachedResumePoint(from: $0)) }
        try upsertSync(endpoint: "resume", count: points.count)
        try context.save()
    }

    func replaceWatchHistory(_ entries: [WatchEntry]) throws {
        let descriptor = FetchDescriptor<CachedWatchEntry>()
        let existing = try context.fetch(descriptor)
        existing.forEach { context.delete($0) }
        entries.forEach { context.insert(CachedWatchEntry(from: $0)) }
        try upsertSync(endpoint: "watched", count: entries.count)
        try context.save()
    }

    func replaceLists(_ lists: [MediaList]) throws {
        let descriptor = FetchDescriptor<CachedMediaList>()
        let existing = try context.fetch(descriptor)
        existing.forEach { context.delete($0) }
        lists.forEach { context.insert(CachedMediaList(from: $0)) }
        try upsertSync(endpoint: "lists", count: lists.count)
        try context.save()
    }

    func replaceListItems(listId: String, items: [ListItem]) throws {
        let descriptor = FetchDescriptor<CachedListItem>(predicate: #Predicate { $0.listId == listId })
        let existing = try context.fetch(descriptor)
        existing.forEach { context.delete($0) }
        
        items.forEach { item in
            context.insert(CachedListItem(
                id: item.id,
                listId: listId,
                tmdbId: item.tmdbId,
                mediaType: item.mediaType.rawValue
            ))
        }
        try context.save()
    }

    func cachedResumePoints() throws -> [CachedResumePoint] {
        try context.fetch(FetchDescriptor<CachedResumePoint>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
    }
    
    func cachedFavorites() throws -> [FavoriteItem] {
        try context.fetch(FetchDescriptor<FavoriteItem>())
    }

    func cachedWatchEntries() throws -> [CachedWatchEntry] {
        try context.fetch(FetchDescriptor<CachedWatchEntry>())
    }

    func cachedLists() throws -> [CachedMediaList] {
        try context.fetch(FetchDescriptor<CachedMediaList>())
    }

    func cachedListItems(listId: String) throws -> [CachedListItem] {
        try context.fetch(FetchDescriptor<CachedListItem>(predicate: #Predicate { $0.listId == listId }))
    }

    private func upsertSync(endpoint endpointName: String, count: Int) throws {
        let descriptor = FetchDescriptor<SyncMetadata>(predicate: #Predicate { $0.endpoint == endpointName })
        if let meta = try context.fetch(descriptor).first {
            meta.lastSyncedAt = .now
            meta.itemCount = count
        } else {
            context.insert(SyncMetadata(endpoint: endpointName, lastSyncedAt: .now, itemCount: count))
        }
    }

    func savePublicList(_ list: MediaList) {
        let posterURLs = list.previewPosters.compactMap { $0?.absoluteString }
        let savedList = SavedPublicList(
            remoteId: list.id,
            name: list.name,
            listDescription: list.description,
            creatorName: list.creatorName,
            itemCount: list.itemCount ?? 0,
            posterURLs: posterURLs
        )
        context.insert(savedList)
        try? context.save()
    }

    func removePublicList(id: String) {
        let descriptor = FetchDescriptor<SavedPublicList>(predicate: #Predicate { $0.remoteId == id })
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    func isPublicListSaved(id: String) throws -> Bool {
        let descriptor = FetchDescriptor<SavedPublicList>(predicate: #Predicate { $0.remoteId == id })
        let count = try context.fetchCount(descriptor)
        return count > 0
    }

    func savedPublicLists() throws -> [SavedPublicList] {
        try context.fetch(FetchDescriptor<SavedPublicList>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)]))
    }
}
