import Foundation

public enum GameBundleID {
    public static let freeFire = "com.dts.freefireth"
    public static let freeFireMax = "com.dts.freefiremax"
    public static let houseArrest = "com.apple.mobile.MobileHouseArrest"
}

public final class ContainerAccess {
    public static let shared = ContainerAccess()

    private let mcm: MCMContainer?

    public init() {
        mcm = MCMContainer.shared
    }

    public var isAvailable: Bool {
        mcm?.isLoaded ?? false
    }

    public func gameContainerPath(bundleID: String) throws -> String {
        // 1) Ưu tiên dataContainerURL từ LSApplicationProxy (kỹ thuật CheatiOS DSW)
        if let path = AppLauncher.containerPath(bundleID: bundleID), !path.isEmpty {
            return path
        }
        // 2) Quét trực tiếp /var/mobile/Containers/Data/Application, đọc
        //    MCMMetadataIdentifier (cách chắc chắn nhất, không cần entitlement)
        if let path = scanContainerPath(bundleID: bundleID) {
            return path
        }
        // 3) Fallback cuối: MCM container query
        guard let mcm = mcm else { throw MCMError.dlopenFailed }
        return try mcm.containerPath(forBundleID: bundleID, cls: .data, part: 0)
    }

    /// Quét toàn bộ data container, khớp bundle ID qua
    /// .com.apple.mobile_container_manager.metadata.plist (MCMMetadataIdentifier).
    private func scanContainerPath(bundleID: String) -> String? {
        let root = "/var/mobile/Containers/Data/Application"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root) else {
            return nil
        }
        for entry in entries {
            let dir = (root as NSString).appendingPathComponent(entry)
            let meta = (dir as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard FileManager.default.fileExists(atPath: meta) else { continue }
            if let dict = NSDictionary(contentsOfFile: meta),
               let ident = dict["MCMMetadataIdentifier"] as? String,
               ident == bundleID {
                return dir
            }
        }
        return nil
    }

    public func gameSandboxToken(bundleID: String) throws -> String {
        guard let mcm = mcm else { throw MCMError.dlopenFailed }
        return try mcm.sandboxToken(forBundleID: bundleID)
    }
}