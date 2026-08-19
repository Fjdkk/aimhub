import Foundation

public enum GameBundleID {
    public static let freeFire = "com.dts.freefireth"
    public static let freeFireMax = "com.dts.freefiremax"
    public static let houseArrest = "com.apple.mobile.MobileHouseArrest"
}

public final class ContainerAccess {
    public static let shared = ContainerAccess()

    /// Nhận log chẩn đoán (AppState gán vào để đẩy vào Nhật ký phiên).
    public static var onDiagnostic: ((String) -> Void)?

    private static func diag(_ message: String) {
        print("[AimHub][Container] \(message)")
        onDiagnostic?(message)
    }

    private let mcm: MCMContainer?

    public init() {
        mcm = MCMContainer.shared
    }

    public var isAvailable: Bool {
        mcm?.isLoaded ?? false
    }

    public func gameContainerPath(bundleID: String) throws -> String {
        Self.diag(">>> gameContainerPath cho \(bundleID)")

        // 0) Log host bundle ID thật để đối chiếu với MobileHouseArrest
        let hostID = Bundle.main.bundleIdentifier ?? "nil"
        Self.diag("Host bundleID = \(hostID)")

        // 1) Ưu tiên dataContainerURL từ LSApplicationProxy (kỹ thuật CheatiOS DSW)
        if let path = AppLauncher.containerPath(bundleID: bundleID), !path.isEmpty {
            Self.diag("Tầng 1 OK: dataContainerURL = \(path)")
            return path
        } else {
            Self.diag("Tầng 1 FAIL: không lấy được dataContainerURL cho \(bundleID)")
            Self.diag("App liệt kê được: \(AppLauncher.debugGameApps().joined(separator: ", "))")
        }

        // 2) Quét trực tiếp /var/mobile/Containers/Data/Application, đọc
        //    MCMMetadataIdentifier (cách chắc chắn nhất, không cần entitlement)
        if let path = scanContainerPath(bundleID: bundleID) {
            Self.diag("Tầng 2 OK: scan container = \(path)")
            return path
        } else {
            Self.diag("Tầng 2 FAIL: không tìm thấy container \(bundleID) khi quét")
        }

        // 3) Fallback cuối: MCM container query
        guard let mcm = mcm else {
            Self.diag("Tầng 3 FAIL: MCM chưa nạp (dlopen thất bại)")
            throw MCMError.dlopenFailed
        }
        do {
            let path = try mcm.containerPath(forBundleID: bundleID, cls: .data, part: 0)
            Self.diag("Tầng 3 OK: MCM path = \(path)")
            return path
        } catch {
            Self.diag("Tầng 3 FAIL: \(error.localizedDescription)")
            throw error
        }
    }

    /// Chẩn đoán host: bundle ID + trạng thái MCM + khả năng quét.
    public func diagnose(bundleID: String) -> [String] {
        var out: [String] = []
        out.append("Host bundleID = \(Bundle.main.bundleIdentifier ?? "nil")")
        out.append("MCM loaded = \(mcm?.isLoaded ?? false)")
        let proxied = AppLauncher.debugGameApps()
        out.append("App game phát hiện được = \(proxied.isEmpty ? "(rỗng)" : proxied.joined(separator: ", "))")
        if let p = AppLauncher.containerPath(bundleID: bundleID) {
            out.append("dataContainerURL = \(p)")
        } else {
            out.append("dataContainerURL = (nil)")
        }
        let scan = scanContainerPath(bundleID: bundleID)
        out.append("Scan container = \(scan ?? "(nil)")")
        return out
    }

    /// Quét toàn bộ data container, khớp bundle ID qua
    /// .com.apple.mobile_container_manager.metadata.plist (MCMMetadataIdentifier).
    private func scanContainerPath(bundleID: String) -> String? {
        let root = "/var/mobile/Containers/Data/Application"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root) else {
            Self.diag("Không đọc được \(root) (bị chặn sandbox?)")
            return nil
        }
        Self.diag("\(root) có \(entries.count) thư mục")
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