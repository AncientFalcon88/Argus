import Foundation
import Security
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published private(set) var publicMetaDBAPIKey: String
    @Published private(set) var tmdbAPIKey: String
    @Published private(set) var contributorName: String
    @Published private(set) var isLoggedIn: Bool

    nonisolated private static let placeholderKeys: Set<String> = [
        "",
        "pm-REPLACE_ME",
        "pm-replace-with-your-api-key",
        "your-tmdb-api-key"
    ]

    private init() {
        let pmKey = KeychainStore.load(account: SettingsKeychainAccount.publicMetaDB.rawValue)
            ?? UserDefaults.standard.string(forKey: SettingsKeychainAccount.publicMetaDB.rawValue)
            ?? ""
        publicMetaDBAPIKey = pmKey
        tmdbAPIKey = KeychainStore.load(account: SettingsKeychainAccount.tmdb.rawValue)
            ?? UserDefaults.standard.string(forKey: SettingsKeychainAccount.tmdb.rawValue)
            ?? ""
        contributorName = UserDefaults.standard.string(forKey: "publicmetadb.contributor.name") ?? ""
        isLoggedIn = !Self.isPlaceholder(pmKey)
    }

    var isPublicMetaDBConfigured: Bool { isLoggedIn }

    var isTMDBConfigured: Bool {
        !Self.isPlaceholder(tmdbAPIKey)
    }

    nonisolated static func isPlaceholder(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if placeholderKeys.contains(trimmed) { return true }
        if trimmed.lowercased().hasPrefix("pm-replace") { return true }
        if trimmed.lowercased().hasPrefix("your-tmdb") { return true }
        return false
    }

    // Called by AuthService after successful login
    func applyLogin(apiKey: String, contributorName: String) {
        self.publicMetaDBAPIKey = apiKey
        self.contributorName = contributorName
        self.isLoggedIn = true
    }

    // Called by AuthService on logout
    func applyLogout() {
        self.publicMetaDBAPIKey = ""
        self.contributorName = ""
        self.isLoggedIn = false
    }

    // Only for TMDB key (manual entry still needed)
    func saveTMDBKey(_ tmdbKey: String) {
        let tmdb = tmdbKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isPlaceholder(tmdb) {
            KeychainStore.delete(account: SettingsKeychainAccount.tmdb.rawValue)
            UserDefaults.standard.removeObject(forKey: SettingsKeychainAccount.tmdb.rawValue)
            tmdbAPIKey = ""
        } else {
            KeychainStore.save(tmdb, account: SettingsKeychainAccount.tmdb.rawValue)
            tmdbAPIKey = tmdb
        }
    }

    // Legacy method kept for backward compatibility — used nowhere new
    func save(publicMetaDBKey: String, tmdbKey: String, contributorName: String? = nil) {
        if let cn = contributorName {
            let cleanCN = cn.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(cleanCN, forKey: "publicmetadb.contributor.name")
            self.contributorName = cleanCN
        }
        saveTMDBKey(tmdbKey)
    }
}

// MARK: - Keychain

enum KeychainStore {
    private static let service = "com.publicmetadb.app.credentials"

    static func save(_ value: String, account: String) {
        delete(account: account)
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
