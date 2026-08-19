import Foundation
import UIKit

public enum KeyStorage {
    private static let defaults = UserDefaults.standard
    private static let key = "aimhub.activeKey"

    public static func save(_ info: KeyInfo) {
        if let data = try? JSONEncoder().encode(info) {
            defaults.set(data, forKey: key)
        }
    }

    public static func load() -> KeyInfo? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyInfo.self, from: data)
    }

    public static func clear() {
        defaults.removeObject(forKey: key)
    }
}

public enum DeviceInfo {
    public static var identifier: String {
        if let existing = UserDefaults.standard.string(forKey: "aimhub.deviceID") {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "aimhub.deviceID")
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