import Foundation
import Security
import UIKit

public enum DeviceInfo {
    private static let service = "com.aimhub.device"
    private static let account = "deviceID"

    public static var identifier: String {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data,
           let id = String(data: data, encoding: .utf8) {
            return id
        }

        let id = UUID().uuidString
        let data = id.data(using: .utf8)!

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
        return id
    }

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
