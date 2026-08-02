import Foundation

struct UserProfile: Sendable, Equatable {
    let name: String
    let avatarUrl: URL?
}

actor UserService {
    static let shared = UserService()
    private var cache: [String: UserProfile] = [:]
    
    func fetchUserProfile(id: String) async -> UserProfile? {
        if let profile = cache[id] { return profile }
        guard let url = URL(string: "https://api.publicmetadb.com/api/collections/users/records/\(id)") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["name"] as? String {
                
                var avatarUrl: URL? = nil
                if let avatar = json["avatar"] as? String, !avatar.isEmpty {
                    avatarUrl = URL(string: "https://api.publicmetadb.com/api/files/users/\(id)/\(avatar)")
                }
                
                let profile = UserProfile(name: name, avatarUrl: avatarUrl)
                cache[id] = profile
                return profile
            }
        } catch {
            print("[UserService] Failed to fetch user: \(error)")
        }
        return nil
    }
    
    // For backwards compatibility
    func fetchUsername(id: String) async -> String? {
        return await fetchUserProfile(id: id)?.name
    }
}
