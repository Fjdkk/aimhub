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

        guard let mcm = mcm else {
            Self.diag("MCM chưa nạp (dlopen thất bại)")
            throw ModManagerError.containerUnavailable
        }
        do {
            let path = try mcm.containerPathBasic(forBundleID: bundleID)
            Self.diag("MCM OK: \(path)")
            return path
        } catch {
            Self.diag("MCM FAIL: \(error.localizedDescription)")
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