import Foundation

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case noAPIKey
    case networkError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Incorrect email or password. Please try again."
        case .noAPIKey:
            return "Logged in but no API key found. Please generate one at publicmetadb.com → Settings → API."
        case .networkError(let msg):
            return msg
        case .decodingError:
            return "Unexpected server response. Please try again."
        }
    }
}

// MARK: - Auth Service

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    private let pbBase = URL(string: "https://api.publicmetadb.com")!
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private init() {}

    // MARK: Login

    func login(identity: String, password: String) async throws {
        let url = pbBase.appendingPathComponent("/api/collections/users/auth-with-password")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["identity": identity.trimmingCharacters(in: .whitespacesAndNewlines),
                    "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 400 {
            throw AuthError.invalidCredentials
        }
        guard status == 200 else {
            throw AuthError.networkError("Server returned status \(status).")
        }

        let authResponse: PocketBaseAuthResponse
        do {
            authResponse = try decoder.decode(PocketBaseAuthResponse.self, from: data)
        } catch {
            throw AuthError.decodingError
        }

        let pbToken = authResponse.token
        let user = authResponse.record

        // Fetch the user's pm- API key
        let apiKey = try await fetchAPIKey(userId: user.id, pbToken: pbToken)

        // Persist everything
        KeychainStore.save(apiKey, account: SettingsKeychainAccount.publicMetaDB.rawValue)
        KeychainStore.save(pbToken, account: SettingsKeychainAccount.pbToken.rawValue)
        UserDefaults.standard.set(user.id, forKey: "publicmetadb.user.id")
        UserDefaults.standard.set(user.name, forKey: "publicmetadb.contributor.name")
        UserDefaults.standard.set(identity, forKey: "publicmetadb.user.identity")

        // Update SettingsStore live
        SettingsStore.shared.applyLogin(apiKey: apiKey, contributorName: user.name)
    }

    // MARK: Fetch API Key

    private func fetchAPIKey(userId: String, pbToken: String) async throws -> String {
        // The /api/create-api-key endpoint creates a new key and returns its full pm- value.
        // Existing keys' values are intentionally hidden from the API for security (only shown on creation).
        let url = URL(string: "https://publicmetadb.com/api/create-api-key")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(pbToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": "Argus"])

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let bodyStr = String(data: data, encoding: .utf8) ?? ""
        print("[Auth] create-api-key status: \(status)")
        print("[Auth] create-api-key body: \(bodyStr)")

        guard status == 200 || status == 201 else {
            throw AuthError.networkError("Failed to create API key (status \(status)): \(bodyStr)")
        }

        // Parse the returned key from the response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for fieldName in ["key", "api_key", "value", "token", "apiKey"] {
                if let key = json[fieldName] as? String, !key.isEmpty {
                    return key
                }
            }
            // Maybe the whole response IS the key data structure
            print("[Auth] Response keys: \(json.keys.sorted())")
        }

        throw AuthError.noAPIKey
    }

    // MARK: Refresh Token
    
    func refreshTokenIfNeeded() async {
        let currentToken = KeychainStore.load(account: SettingsKeychainAccount.pbToken.rawValue) ?? ""
        guard !currentToken.isEmpty else { return }
        
        let url = pbBase.appendingPathComponent("/api/collections/users/auth-refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let authResponse = try? decoder.decode(PocketBaseAuthResponse.self, from: data) {
                    KeychainStore.save(authResponse.token, account: SettingsKeychainAccount.pbToken.rawValue)
                    print("[Auth] Token successfully refreshed.")
                }
            } else if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 401 {
                print("[Auth] Token expired or invalid, user must login again.")
                await MainActor.run {
                    self.logout()
                }
            }
        } catch {
            print("[Auth] Token refresh network error: \(error)")
        }
    }

    // MARK: Logout

    func logout() {
        KeychainStore.delete(account: SettingsKeychainAccount.publicMetaDB.rawValue)
        KeychainStore.delete(account: SettingsKeychainAccount.pbToken.rawValue)
        UserDefaults.standard.removeObject(forKey: "publicmetadb.user.id")
        UserDefaults.standard.removeObject(forKey: "publicmetadb.contributor.name")
        UserDefaults.standard.removeObject(forKey: "publicmetadb.user.identity")
        SettingsStore.shared.applyLogout()
    }
}
