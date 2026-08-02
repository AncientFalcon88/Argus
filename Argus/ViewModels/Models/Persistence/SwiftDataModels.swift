import Foundation
import SwiftData

@Model
final class CachedResumePoint {
    @Attribute(.unique) var cacheKey: String
    var remoteId: String
    var tmdbId: Int
    var mediaType: String
    var season: Int?
    var episode: Int?
    var positionMs: Int
    var runtimeMs: Int?
    var progress: Double
    var title: String?
    var posterPath: String?
    var updatedAt: Date
    var updatedAtString: String?  // the raw ISO8601 string from the API, used for stable sort

    init(
        cacheKey: String = "",
        remoteId: String = "",
        tmdbId: Int = 0,
        mediaType: String = MediaType.movie.rawValue,
        season: Int? = nil,
        episode: Int? = nil,
        positionMs: Int = 0,
        runtimeMs: Int? = nil,
        progress: Double = 0,
        title: String? = nil,
        posterPath: String? = nil,
        updatedAt: Date = .now,
        updatedAtString: String? = nil
    ) {
        self.cacheKey = cacheKey
        self.remoteId = remoteId
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.positionMs = positionMs
        self.runtimeMs = runtimeMs
        self.progress = progress
        self.title = title
        self.posterPath = posterPath
        self.updatedAt = updatedAt
        self.updatedAtString = updatedAtString
    }

    convenience init(from point: ResumePoint) {
        self.init(
            cacheKey: Self.key(
                tmdbId: point.tmdbId,
                mediaType: point.mediaType.rawValue,
                season: point.season,
                episode: point.episode
            ),
            remoteId: point.id,
            tmdbId: point.tmdbId,
            mediaType: point.mediaType.rawValue,
            season: point.season,
            episode: point.episode,
            positionMs: point.positionMs,
            runtimeMs: point.runtimeMs,
            progress: point.progressFraction,
            title: point.title,
            posterPath: point.posterPath,
            updatedAt: {
                if let s = point.updatedAt {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f.date(from: s) ?? .now
                }
                return .now
            }(),
            updatedAtString: point.updatedAt
        )
    }

    static func key(tmdbId: Int, mediaType: String, season: Int?, episode: Int?) -> String {
        "\(mediaType)-\(tmdbId)-\(season ?? 0)-\(episode ?? 0)"
    }
}

@Model
final class CachedWatchEntry {
    @Attribute(.unique) var remoteId: String
    var tmdbId: Int
    var mediaType: String
    var season: Int?
    var episode: Int?
    var watchedAt: String?
    var title: String?
    var posterPath: String?
    var backdropPath: String?
    var syncedAt: Date

    init(
        remoteId: String = "",
        tmdbId: Int = 0,
        mediaType: String = MediaType.movie.rawValue,
        season: Int? = nil,
        episode: Int? = nil,
        watchedAt: String? = nil,
        title: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        syncedAt: Date = .now
    ) {
        self.remoteId = remoteId
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.watchedAt = watchedAt
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.syncedAt = syncedAt
    }

    convenience init(from entry: WatchEntry) {
        self.init(
            remoteId: entry.id,
            tmdbId: entry.tmdbId,
            mediaType: entry.mediaType.rawValue,
            season: entry.season,
            episode: entry.episode,
            watchedAt: entry.watchedAt,
            title: entry.title,
            posterPath: entry.posterPath,
            backdropPath: entry.backdropPath,
            syncedAt: .now
        )
    }
}

@Model
final class CachedMediaList {
    @Attribute(.unique) var remoteId: String
    var name: String
    var listDescription: String?
    var isPublic: Bool
    var itemCount: Int
    var posterURLs: [String] = []
    var syncedAt: Date

    init(
        remoteId: String = "",
        name: String = "",
        listDescription: String? = nil,
        isPublic: Bool = true,
        itemCount: Int = 0,
        posterURLs: [String] = [],
        syncedAt: Date = .now
    ) {
        self.remoteId = remoteId
        self.name = name
        self.listDescription = listDescription
        self.isPublic = isPublic
        self.itemCount = itemCount
        self.posterURLs = posterURLs
        self.syncedAt = syncedAt
    }

    convenience init(from list: MediaList) {
        self.init(
            remoteId: list.id,
            name: list.name,
            listDescription: list.description,
            isPublic: list.isPublic,
            itemCount: list.itemCount ?? 0,
            posterURLs: list.previewPosters.compactMap { $0?.absoluteString },
            syncedAt: .now
        )
    }

    func toMediaList() -> MediaList {
        var ml = MediaList(
            id: remoteId,
            name: name,
            description: listDescription,
            isPublic: isPublic,
            type: nil,
            itemCount: itemCount,
            createdAt: nil,
            updatedAt: nil
        )
        ml.previewPosters = posterURLs.compactMap { URL(string: $0) }
        return ml
    }
}

@Model
final class SyncMetadata {
    @Attribute(.unique) var endpoint: String
    var lastSyncedAt: Date?
    var itemCount: Int

    init(endpoint: String = "", lastSyncedAt: Date? = nil, itemCount: Int = 0) {
        self.endpoint = endpoint
        self.lastSyncedAt = lastSyncedAt
        self.itemCount = itemCount
    }
}

@Model
final class SavedPublicList {
    @Attribute(.unique) var remoteId: String
    var name: String
    var listDescription: String?
    var creatorName: String?
    var itemCount: Int
    var posterURLs: [String]
    var savedAt: Date

    init(
        remoteId: String,
        name: String,
        listDescription: String? = nil,
        creatorName: String? = nil,
        itemCount: Int = 0,
        posterURLs: [String] = [],
        savedAt: Date = .now
    ) {
        self.remoteId = remoteId
        self.name = name
        self.listDescription = listDescription
        self.creatorName = creatorName
        self.itemCount = itemCount
        self.posterURLs = posterURLs
        self.savedAt = savedAt
    }
}

@Model
final class CachedListItem {
    @Attribute(.unique) var id: String
    var listId: String
    var tmdbId: Int
    var mediaType: String
    var syncedAt: Date

    init(id: String = "", listId: String = "", tmdbId: Int = 0, mediaType: String = "", syncedAt: Date = .now) {
        self.id = id
        self.listId = listId
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.syncedAt = syncedAt
    }
}
