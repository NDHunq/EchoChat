//
//  KeychainManager.swift
//  EchoChat
//
//  Secure key-value storage backed by the iOS Keychain.
//  Replaces UserDefaults / @AppStorage for sensitive user data such as identity.
//

import Foundation
import Security

struct KeychainManager {

    // MARK: - Singleton

    static let shared = KeychainManager()
    private init() {}

    // MARK: - Well-known Keys

    /// The Keychain key used to persist the current user's display name / ID.
    static let currentUserKey = "com.echochat.currentUser"

    // MARK: - Save

    /// Saves (or updates) a string value for the given key in the Keychain.
    /// - Returns: `true` if the operation succeeded.
    @discardableResult
    func save(key: String, data: String) -> Bool {
        guard let encoded = data.data(using: .utf8) else { return false }

        // Build the base query that identifies the item.
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     Bundle.main.bundleIdentifier ?? "com.echochat",
            kSecAttrAccount:     key
        ]

        // Try to update an existing item first.
        let updateAttributes: [CFString: Any] = [kSecValueData: encoded]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        }

        // Item does not exist yet — add it.
        var addQuery = query
        addQuery[kSecValueData]                   = encoded
        // Only accessible when the device is unlocked (not backed up to iCloud).
        addQuery[kSecAttrAccessible]              = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            print("[KeychainManager] Save failed for key '\(key)': OSStatus \(addStatus)")
        }
        return addStatus == errSecSuccess
    }

    // MARK: - Load

    /// Loads a string value for the given key from the Keychain.
    /// - Returns: The stored string, or `nil` if not found or an error occurred.
    func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      Bundle.main.bundleIdentifier ?? "com.echochat",
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            if status != errSecItemNotFound {
                print("[KeychainManager] Load failed for key '\(key)': OSStatus \(status)")
            }
            return nil
        }
        return string
    }

    // MARK: - Delete

    /// Removes the item for the given key from the Keychain.
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  Bundle.main.bundleIdentifier ?? "com.echochat",
            kSecAttrAccount:  key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
