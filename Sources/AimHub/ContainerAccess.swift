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

        // Tier 1: MCM Container Access (Bắt buộc chạy trực tiếp để kích hoạt Sandbox Extension cho process)
        if let mcm = mcm {
            do {
                let path = try mcm.containerPathBasic(forBundleID: bundleID)
                Self.diag("[Tier1] ✅ MCM basic OK: \(path)")
                return path
            } catch {
                Self.diag("[Tier1] ⚠️ MCM basic FAIL: \(error.localizedDescription)")
            }

            do {
                let path = try mcm.containerPath(forBundleID: bundleID)
                Self.diag("[Tier1] ✅ MCM advanced OK: \(path)")
                return path
            } catch {
                Self.diag("[Tier1] ⚠️ MCM advanced FAIL: \(error.localizedDescription)")
            }

            do {
                if let path = try mcm.containerPathByIterating(forBundleID: bundleID) {
                    Self.diag("[Tier1] ✅ MCM iterate OK: \(path)")
                    return path
                }
            } catch {
                Self.diag("[Tier1] ⚠️ MCM iterate FAIL: \(error.localizedDescription)")
            }
        } else {
            Self.diag("[Tier1] ⚠️ MCM không khả dụng (dlopen failed)")
        }

        // Tier 2: Kernel Sandbox Escape (KExploit cho iOS 14 - 16.1.2)
        if KExploitEngine.shared.tryEscapeSandbox() {
            Self.diag("[Tier2] ✅ KExploit kích hoạt thành công")
        } else {
            Self.diag("[Tier2] ⚠️ KExploit không khả dụng")
        }

        // Tier 3: LaunchServices LSApplicationProxy (via canmaplsdatabase)
        if let lsPath = AppLauncher.containerPath(bundleID: bundleID) {
            Self.diag("[Tier3] ✅ LaunchServices container OK: \(lsPath)")
            ContainerCacheStore.shared.setCachedPath(lsPath, for: bundleID)
            return lsPath
        } else {
            Self.diag("[Tier3] LaunchServices FAIL")
        }

        // Tier 4: Direct Containers Filesystem Scan (POSIX + FileManager)
        let appsRoots = [
            "/private/var/mobile/Containers/Data/Application",
            "/var/mobile/Containers/Data/Application"
        ]
        for appsRoot in appsRoots {
            var subDirs: [String] = []
            if let dir = opendir(appsRoot) {
                while let entry = readdir(dir) {
                    let name = withUnsafeBytes(of: entry.pointee.d_name) { ptr -> String in
                        let cStr = ptr.baseAddress!.assumingMemoryBound(to: CChar.self)
                        return String(cString: cStr)
                    }
                    if name != "." && name != ".." {
                        subDirs.append(name)
                    }
                }
                closedir(dir)
            }
            if subDirs.isEmpty {
                subDirs = (try? FileManager.default.contentsOfDirectory(atPath: appsRoot)) ?? []
            }
            if !subDirs.isEmpty {
                Self.diag("Scanning \(subDirs.count) app containers in \(appsRoot)...")
                for sub in subDirs {
                    let candidatePath = "\(appsRoot)/\(sub)"
                    let metaPath = "\(candidatePath)/.com.apple.mobile_container_manager.metadata.plist"
                    if let data = try? POSIXFile.read(from: metaPath),
                       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                       let ident = plist["MCMMetadataIdentifier"] as? String,
                       ident == bundleID {
                        Self.diag("Found container by metadata: \(candidatePath)")
                        return candidatePath
                    }
                }
            }
        }

        // Tier 5: HouseArrest Documents Lookup
        if let docPath = HouseArrestClient.shared.lookupDocumentsPath(for: bundleID) {
            Self.diag("HouseArrest container OK: \(docPath)")
            let rootPath = (docPath as NSString).deletingLastPathComponent
            return rootPath
        }

        // Tier 6: AirLift CoreDevice Tunnel
        if AirLiftPairingStore.shared.isPaired {
            Self.diag("AirLift Tunnel is paired and ready as active transport")
        }

        Self.diag("[FAIL] ❌ Tất cả 6 tier đều thất bại cho \(bundleID) → Không tìm được container game")
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