import Foundation
import Security

// MARK: - Keychain Manager

enum KeychainManager {
    static func save(key: String, value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.zh.hi.trans",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status)
        }
    }

    static func read(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.zh.hi.trans",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.readFailed(status)
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.zh.hi.trans"
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    enum KeychainError: LocalizedError {
        case writeFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .writeFailed(let s): return "Keychain 写入失败 (\(s))"
            case .readFailed(let s): return "Keychain 读取失败 (\(s))"
            case .deleteFailed(let s): return "Keychain 删除失败 (\(s))"
            }
        }
    }
}

// MARK: - App Config

enum AppConfig {
    static var isAutoCopyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoCopy") }
        set { UserDefaults.standard.set(newValue, forKey: "autoCopy") }
    }

    static var apiKey: String {
        get throws {
            if let key = try KeychainManager.read(key: "deepseek_api_key"), !key.isEmpty {
                return key
            }
            throw TranslationError.missingAPIKey
        }
    }

    static func saveAPIKey(_ key: String) throws {
        try KeychainManager.save(key: "deepseek_api_key", value: key)
    }

    static var hasAPIKey: Bool {
        (try? KeychainManager.read(key: "deepseek_api_key")).flatMap { $0.isEmpty == false } ?? false
    }
}
