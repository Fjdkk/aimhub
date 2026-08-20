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

        // 3) MCM container query theo tên
        guard let mcm = mcm else {
            Self.diag("Tầng 3 FAIL: MCM chưa nạp (dlopen thất bại)")
            throw MCMError.dlopenFailed
        }
        var lastError: Error? = nil
        do {
            let path = try mcm.containerPath(forBundleID: bundleID, cls: .data, part: 0)
            Self.diag("Tầng 3 OK: MCM path = \(path)")
            return path
        } catch {
            lastError = error
            Self.diag("Tầng 3 FAIL: \(error.localizedDescription)")
        }

        // 3.5) MCM iterate toàn bộ data container rồi khớp identifier
        do {
            if let path = try mcm.containerPathByIterating(forBundleID: bundleID, cls: .data) {
                Self.diag("Tầng 3.5 OK: iterate khớp = \(path)")
                return path
            }
            Self.diag("Tầng 3.5 FAIL: iterate không khớp container nào")
        } catch {
            Self.diag("Tầng 3.5 FAIL: \(error.localizedDescription)")
        }

        throw lastError ?? MCMError.queryFailed("unknown")
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
        if let mcm = mcm {
            do {
                if let p = try mcm.containerPathByIterating(forBundleID: bundleID, cls: .data) {
                    out.append("MCM iterate = \(p)")
                } else {
                    out.append("MCM iterate = (không khớp)")
                }
            } catch {
                out.append("MCM iterate FAIL: \(error.localizedDescription)")
            }
        } else {
            out.append("MCM iterate = (chưa nạp)")
        }
        return out
    }

    /// Quét toàn bộ data container bằng POSIX opendir (tránh Foundation bị
    /// chặn sandbox), khớp bundle ID qua
    /// .com.apple.mobile_container_manager.metadata.plist (MCMMetadataIdentifier).
    private func scanContainerPath(bundleID: String) -> String? {
        let root = "/var/mobile/Containers/Data/Application"
        guard let dir = opendir(root) else {
            Self.diag("opendir \(root) thất bại errno=\(errno) (\(strerror(errno) ?? ""))")
            return nil
        }
        defer { closedir(dir) }

        var count = 0
        var matches: [String] = []
        while let ent = readdir(dir) {
            let name = withUnsafeBytes(of: &ent.pointee.d_name) { raw -> String in
                let buf = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
                return String(cString: buf)
            }
            if name == "." || name == ".." { continue }
            count += 1
            let containerDir = (root as NSString).appendingPathComponent(name)
            let metaPath = (containerDir as NSString)
                .appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let ident = readMetadataIdentifier(at: metaPath) else { continue }
            if ident == bundleID {
                matches.append(containerDir)
            }
        }
        Self.diag("\(root) có \(count) thư mục, khớp \(matches.count) với \(bundleID)")
        return matches.first
    }

    /// Đọc MCMMetadataIdentifier từ metadata plist bằng POSIX (tránh Foundation).
    private func readMetadataIdentifier(at path: String) -> String? {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var st = stat()
        guard fstat(fd, &st) == 0, st.st_size > 0, st.st_size < 4_000_000 else { return nil }
        var data = Data(count: Int(st.st_size))
        let n = data.withUnsafeMutableBytes { (buf: UnsafeMutableRawBufferPointer) -> Int in
            Darwin.read(fd, buf.baseAddress, buf.count)
        }
        guard n == data.count else { return nil }

        // Đọc qua CFPropertyList (CoreFoundation thuần, không qua Foundation sandbox)
        guard let cfData = CFDataCreate(nil, (data as NSData).bytes.assumingMemoryBound(to: UInt8.self), data.count) else {
            return nil
        }
        var fmt = CFPropertyListFormat.binaryFormat_v1_0
        guard let plist = CFPropertyListCreateWithData(nil, cfData, CFPropertyListMutabilityOptions.mutableContainersAndLeaves.rawValue, &fmt, nil) else {
            return nil
        }
        guard let dict = plist as? [String: Any] else { return nil }
        return dict["MCMMetadataIdentifier"] as? String
    }

    public func gameSandboxToken(bundleID: String) throws -> String {
        guard let mcm = mcm else { throw MCMError.dlopenFailed }
        return try mcm.sandboxToken(forBundleID: bundleID)
    }
}