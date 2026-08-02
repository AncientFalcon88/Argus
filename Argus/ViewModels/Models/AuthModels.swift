import Foundation

// MARK: - PocketBase Auth Response

struct PocketBaseAuthResponse: Codable {
    let token: String
    let record: PBUserRecord
}

struct PBUserRecord: Codable {
    let id: String
    let name: String
    let email: String?
    let avatar: String?
    let emailVisibility: Bool?
    let verified: Bool?
    let created: String?
    let updated: String?
}

// MARK: - API Keys Collection

struct PBApiKeysResponse: Codable {
    let items: [PBApiKey]
    let page: Int?
    let perPage: Int?
    let totalItems: Int?
}

struct PBApiKey: Codable {
    let id: String
    let key: String?
    let name: String?
    let user: String?
    let created: String?
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, key, name, user, created
        case expiresAt = "expires_at"
    }
}
