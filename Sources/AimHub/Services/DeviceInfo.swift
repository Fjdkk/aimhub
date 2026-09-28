import Foundation
import Security
import UIKit

/// Lưu key trên Keychain (survive app reinstall, không bị xoá như UserDefaults).
public enum KeyStorage {
    private static let service = "com.aimhub.keystore"
    private static let account = "activeKey"

    public static func save(_ info: KeyInfo) {
        guard let data = try? JSONEncoder().encode(info) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let attrs: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(updateQuery as CFDictionary, attrs as CFDictionary)
        }
    }

    public static func load() -> KeyInfo? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(KeyInfo.self, from: data)
    }

    public static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum DeviceInfo {
    private static let service = "com.aimhub.device"
    private static let account = "deviceID"
    private static let userDefaultsKey = "aimhub.persistent.deviceID"
    private static let sandboxFileName = ".aimhub_device_id"

    /// Cache bộ nhớ trong phiên chạy app để tránh I/O liên tục
    private static var cachedID: String?

    /// Mã thiết bị CỐ ĐỊNH 100% không bao giờ nhảy qua 3 tầng lưu trữ:
    /// Tầng 1: Keychain (kSecAttrAccessibleAlwaysThisDeviceOnly)
    /// Tầng 2: File ẩn trong Documents Sandbox (.aimhub_device_id)
    /// Tầng 3: UserDefaults
    public static var identifier: String {
        if let mem = cachedID, !mem.isEmpty {
            return mem
        }

        // 1. Đọc từ Keychain
        if let id = keychainValue(), !id.isEmpty {
            syncToAllLayers(id)
            cachedID = id
            return id
        }

        // 2. Đọc từ Sandbox Documents File
        if let id = fileValue(), !id.isEmpty {
            syncToAllLayers(id)
            cachedID = id
            return id
        }

        // 3. Đọc từ UserDefaults
        if let id = UserDefaults.standard.string(forKey: userDefaultsKey), !id.isEmpty {
            syncToAllLayers(id)
            cachedID = id
            return id
        }

        // 4. Nếu là lần đầu chạy app hoàn toàn: Lấy identifierForVendor hoặc tạo UUID mới
        let newID: String
        if let vendor = UIDevice.current.identifierForVendor?.uuidString, !vendor.isEmpty {
            newID = vendor
        } else {
            newID = UUID().uuidString
        }

        syncToAllLayers(newID)
        cachedID = newID
        return newID
    }

    private static func syncToAllLayers(_ id: String) {
        saveToKeychain(id)
        saveToFile(id)
        UserDefaults.standard.set(id, forKey: userDefaultsKey)
    }

    // MARK: - Keychain Layer
    private static func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func keychainValue() -> String? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8) else {
            return nil
        }
        return id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func saveToKeychain(_ id: String) {
        guard let data = id.data(using: .utf8) else { return }
        var addQuery = keychainQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery = keychainQuery()
            let attrs: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            SecItemUpdate(updateQuery as CFDictionary, attrs as CFDictionary)
        }
    }

    // MARK: - Sandbox File Layer
    private static var sandboxFilePath: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sandboxFileName)
    }

    private static func fileValue() -> String? {
        guard let url = sandboxFilePath,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func saveToFile(_ id: String) {
        guard let url = sandboxFilePath else { return }
        try? id.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - System Info
    public static var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let bytes = mirror.children.map { $0.value as! Int8 }
        var name = ""
        for b in bytes where b != 0 {
            name.append(Character(UnicodeScalar(UInt8(bitPattern: b))))
        }
        return name.isEmpty ? UIDevice.current.model : name
    }

    public static var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
}
