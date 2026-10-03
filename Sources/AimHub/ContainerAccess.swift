import Foundation
import Darwin

public enum GameBundleID {
    public static let freeFire = "com.dts.freefireth"
    public static let freeFireMax = "com.dts.freefiremax"
    public static let houseArrest = "com.apple.mobile.MobileHouseArrest"
}

public final class ContainerAccess {
    public static let shared = ContainerAccess()

    /// Nhận log chẩn đoán (AppState gán vào để đẩy vào Nhật ký phiên).
    public static var onDiagnostic: ((String) -> Void)?

    public static func diag(_ message: String) {
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
        let hostID = Bundle.main.bundleIdentifier ?? "nil"
        Self.diag("Host bundleID = \(hostID)")

        // Tier 1: MCM Basic
        if let mcm = mcm {
            _ = mcm.escapeSandboxViaSystemGroup()
            do {
                let path = try mcm.containerPathBasic(forBundleID: bundleID)
                Self.diag("MCM basic OK: \(path)")
                return path
            } catch {
                Self.diag("MCM basic FAIL: \(error.localizedDescription)")
            }

            // Tier 2: MCM Advanced / Iterate
            do {
                let path = try mcm.containerPath(forBundleID: bundleID)
                Self.diag("MCM advanced OK: \(path)")
                return path
            } catch {
                Self.diag("MCM advanced FAIL: \(error.localizedDescription)")
            }

            do {
                if let path = try mcm.containerPathByIterating(forBundleID: bundleID) {
                    Self.diag("MCM by iterating OK: \(path)")
                    return path
                }
            } catch {
                Self.diag("MCM iterate FAIL: \(error.localizedDescription)")
            }
        }

        // Tier 3: LaunchServices LSApplicationProxy (via canmaplsdatabase)
        if let lsPath = AppLauncher.containerPath(bundleID: bundleID) {
            Self.diag("LaunchServices container OK: \(lsPath)")
            return lsPath
        }

        // Tier 4: Direct Containers Filesystem Scan (TrollStore / Jailed FS / iOS 16)
        let appsRoot = "/var/mobile/Containers/Data/Application"
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: appsRoot) {
            Self.diag("Scanning \(contents.count) app containers in \(appsRoot)...")
            for sub in contents {
                let candidatePath = "\(appsRoot)/\(sub)"
                let metaPath = "\(candidatePath)/.com.apple.mobile_container_manager.metadata.plist"
                if fm.fileExists(atPath: metaPath) {
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: metaPath)),
                       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                       let ident = plist["MCMMetadataIdentifier"] as? String,
                       ident == bundleID {
                        Self.diag("Found container by metadata: \(candidatePath)")
                        return candidatePath
                    }
                }
            }
        }

        Self.diag(">>> Tất cả phương pháp thất bại cho \(bundleID)")
        throw ModManagerError.containerUnavailable
    }

    /// Chẩn đoán host: bundle ID + trạng thái MCM.
    public func diagnose(bundleID: String) -> [String] {
        var out: [String] = []
        out.append("Host bundleID = \(Bundle.main.bundleIdentifier ?? "nil")")
        out.append("MCM loaded = \(mcm?.isLoaded ?? false)")
        if let mcm = mcm {
            do {
                let p = try mcm.containerPathBasic(forBundleID: bundleID)
                out.append("MCM basic = \(p)")
            } catch {
                out.append("MCM basic FAIL: \(error.localizedDescription)")
            }
        } else {
            out.append("MCM basic = (chưa nạp)")
        }
        return out
    }
}