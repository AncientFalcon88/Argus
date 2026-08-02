import Foundation

struct MultiStatusResponse: Codable {
    let successCount: Int
    let failedCount: Int
    let errors: [String]?
}

struct CreateListResponse: Codable {
    let success: Bool
    let message: String?
    let listId: String?
    let list: MediaList?
    let item: MediaList?
}

extension Notification.Name {
    static let watchStateDidChange = Notification.Name("watchStateDidChange")
}
