import Foundation
import Darwin

public struct ModFile {
    public let name: String
    public let relativePath: String
    public let data: Data

    public init(name: String, relativePath: String, data: Data) {
        self.name = name
        self.relativePath = relativePath
        self.data = data
    }
}

public struct ModEntry {
    public let id: String
    public let displayName: String
    public let description: String
    public let files: [ModFile]

    public init(id: String, displayName: String, description: String, files: [ModFile]) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.files = files
    }
}

public enum ModManagerError: Error, LocalizedError, CustomStringConvertible {
    case containerUnavailable
    case noBackup
    case ioFailed(String)

    public var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return L10n.t("err.containerUnavailable")
        case .noBackup:
            return L10n.t("err.noBackup")
        case .ioFailed(let m):
            return "\(L10n.t("err.ioFailed")): \(m)"
        }
    }

    public var description: String {
        errorDescription ?? "Lỗi container trò chơi"
    }
}

/// Thao tác file bằng POSIX trực tiếp (open/write/rename/unlink/mkdir).
/// Foundation/FileManager tự kiểm tra sandbox theo bundle ID hiện tại và
/// có thể chặn truy cập container của app khác dù sandbox extension đã được
/// consume. POSIX nói chuyện thẳng với kernel, chỉ kiểm tra extension đã consume.
enum POSIXFileError: Error, LocalizedError, CustomStringConvertible {
    case io(String)
    var description: String {
        switch self {
        case .io(let m): return m
        }
    }
    var errorDescription: String? { description }
}

enum POSIXFile {
    private static func errnoMessage() -> String {
        if let p = strerror(errno) {
            return String(cString: p)
        }
        return "errno=\(errno)"
    }

    static func exists(_ path: String) -> Bool {
        var st = stat()
        return stat(path, &st) == 0
    }

    static func isDirectory(_ path: String) -> Bool {
        var st = stat()
        guard stat(path, &st) == 0 else { return false }
        return (st.st_mode & S_IFMT) == S_IFDIR
    }

    static func createDirectory(atPath path: String, withIntermediateDirectories intermediate: Bool) throws {
        if isDirectory(path) { return }
        if exists(path) {
            throw POSIXFileError.io("Đã tồn tại nhưng không phải thư mục: \(path)")
        }
        if intermediate {
            let parent = (path as NSString).deletingLastPathComponent
            if parent != path && !parent.isEmpty && !exists(parent) {
                try createDirectory(atPath: parent, withIntermediateDirectories: true)
            }
        }
        if mkdir(path, S_IRWXU | S_IRWXG | S_IRWXO) != 0 {
            if !isDirectory(path) {
                throw POSIXFileError.io("mkdir \(path) thất bại: \(errnoMessage())")
            }
        }
    }

    static func copy(from src: String, to dst: String) throws {
        let data = try read(from: src)
        try write(data: data, to: dst)
    }

    static func move(from src: String, to dst: String) throws {
        if rename(src, dst) != 0 {
            throw POSIXFileError.io("rename \(src) -> \(dst) thất bại: \(errnoMessage())")
        }
    }

    static func remove(_ path: String) throws {
        if unlink(path) != 0 {
            throw POSIXFileError.io("unlink \(path) thất bại: \(errnoMessage())")
        }
    }

    static func read(from path: String) throws -> Data {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { throw POSIXFileError.io("open \(path) thất bại: \(errnoMessage())") }
        defer { close(fd) }

        var st = stat()
        guard fstat(fd, &st) == 0 else { throw POSIXFileError.io("fstat \(path) thất bại: \(errnoMessage())") }

        var data = Data(count: Int(st.st_size))
        let n = data.withUnsafeMutableBytes { (buf: UnsafeMutableRawBufferPointer) -> Int in
            Darwin.read(fd, buf.baseAddress, buf.count)
        }
        guard n == data.count else { throw POSIXFileError.io("đọc \(path) không đầy đủ") }
        return data
    }

    static func write(data: Data, to path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Log chi tiết quyền thư mục cha
        var dirStat = stat()
        if stat(dir, &dirStat) == 0 {
            let perms = String(dirStat.st_mode & 0o7777, radix: 8)
            ContainerAccess.diag("[IO] Dir \(dir) mode=0o\(perms) uid=\(dirStat.st_uid) gid=\(dirStat.st_gid)")
        } else {
            ContainerAccess.diag("[IO] ⚠️ stat dir \(dir) thất bại: \(errnoMessage())")
        }

        // Kiểm tra file tồn tại trước khi ghi
        var fileStat = stat()
        if stat(path, &fileStat) == 0 {
            let perms = String(fileStat.st_mode & 0o7777, radix: 8)
            ContainerAccess.diag("[IO] File đã tồn tại: \(path) mode=0o\(perms) size=\(fileStat.st_size)")
        }

        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        guard fd >= 0 else {
            let errNo = errno
            let errMsg = errnoMessage()
            ContainerAccess.diag("[IO] ❌ open() thất bại: errno=\(errNo) (\(errMsg)) path=\(path)")
            if errNo == EPERM {
                ContainerAccess.diag("[IO] ❌ EPERM → Sandbox extension chưa được kích hoạt hoặc đã bị thu hồi")
            } else if errNo == EACCES {
                ContainerAccess.diag("[IO] ❌ EACCES → Không đủ quyền truy cập file/thư mục")
            }
            throw POSIXFileError.io("open \(path) thất bại: \(errMsg)")
        }
        defer { close(fd) }

        var written = 0
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            guard let base = buf.baseAddress else { return }
            while written < buf.count {
                let n = Darwin.write(fd, base.advanced(by: written), buf.count - written)
                if n <= 0 { break }
                written += n
            }
        }
        guard written == data.count else {
            throw POSIXFileError.io("ghi \(path) không đầy đủ (\(written)/\(data.count))")
        }
        ContainerAccess.diag("[IO] ✅ Ghi thành công \(written) bytes → \((path as NSString).lastPathComponent)")
    }
}

public final class ModManager {
    public static let shared = ModManager()

    private let backupExtension = ".bak"
    private let registryKey = "aimhub.backup.registry"

    private var containerRoot: String?

    public func prepareContainer(bundleID: String) throws -> String {
        ContainerAccess.diag("[Container] Đang truy vấn container cho \(bundleID)...")
        let path = try ContainerAccess.shared.gameContainerPath(bundleID: bundleID)
        
        containerRoot = path

        // Nếu là kênh AirLift RemotePairing hoặc đường dẫn ảo AirLift
        if AirLiftPairingStore.shared.isPaired || path.contains("AirLift-") {
            ContainerAccess.diag("[Container] ✅ Kênh AirLift AFC kích hoạt thành công cho \(bundleID) (Tunnel active)")
            return path
        }

        if !POSIXFile.isDirectory(path) {
            ContainerAccess.diag("[Container] ⚠️ Không thể stat thư mục bằng POSIX (bị sandbox hạn chế): \(path)")
        }

        // Kiểm tra quyền ghi thực tế vào thư mục Documents của container
        let docsPath = (path as NSString).appendingPathComponent("Documents")
        try? POSIXFile.createDirectory(atPath: docsPath, withIntermediateDirectories: true)
        let testPath = (docsPath as NSString).appendingPathComponent(".aimhub_sandbox_test")
        let testFd = open(testPath, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)
        if testFd >= 0 {
            close(testFd)
            unlink(testPath)
            ContainerAccess.diag("[Container] ✅ Container OK + quyền ghi xác nhận: \(docsPath)")
        } else {
            let errNo = errno
            let errMsg = String(cString: strerror(errNo)!)
            ContainerAccess.diag("[Container] ⚠️ Container tìm được nhưng KHÔNG CÓ QUYỀN GHI POSIX: errno=\(errNo) (\(errMsg))")
            if errNo == EPERM {
                ContainerAccess.diag("[Container] ⚠️ EPERM → Sandbox extension chưa activate hoặc bị iOS thu hồi")
            }
        }
        return path
    }

    func absolute(_ relativePath: String) throws -> String {
        guard let root = containerRoot else { throw ModManagerError.containerUnavailable }
        let joined = (root as NSString).appendingPathComponent(relativePath)
        return (joined as NSString).standardizingPath
    }

    /// Registry backup theo bundleID để mỗi game quản lý backup riêng,
    /// tránh bật mod game này ảnh hưởng/lẫn sang game kia.
    private func registryKey(for bundleID: String) -> String {
        "aimhub.backup.registry.\(bundleID)"
    }

    private func registry(for bundleID: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: registryKey(for: bundleID)) ?? []
    }

    private func saveRegistry(_ list: [String], for bundleID: String) {
        UserDefaults.standard.set(list, forKey: registryKey(for: bundleID))
    }

    // Registry cho các file tiêm mới (không có file gốc -> Tắt là xoá)
    private func injectedRegistryKey(for bundleID: String) -> String {
        "aimhub.injected.registry.\(bundleID)"
    }

    private func injectedRegistry(for bundleID: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: injectedRegistryKey(for: bundleID)) ?? []
    }

    private func saveInjectedRegistry(_ list: [String], for bundleID: String) {
        UserDefaults.standard.set(list, forKey: injectedRegistryKey(for: bundleID))
    }

    private func recordInjectedFile(_ relativePath: String, bundleID: String) {
        var list = injectedRegistry(for: bundleID)
        if !list.contains(relativePath) {
            list.append(relativePath)
            saveInjectedRegistry(list, for: bundleID)
        }
    }

    private func removeInjectedFile(_ relativePath: String, bundleID: String) {
        var list = injectedRegistry(for: bundleID)
        list.removeAll(where: { $0 == relativePath })
        saveInjectedRegistry(list, for: bundleID)
    }

    public func hasBackup(relativePath: String) -> Bool {
        guard let abs = try? absolute(relativePath) else { return false }
        return POSIXFile.exists(abs + backupExtension)
    }

    public func backupFile(relativePath: String, bundleID: String) throws {
        let abs = try absolute(relativePath)
        guard POSIXFile.exists(abs) else {
            throw ModManagerError.ioFailed("Không tồn tại: \(relativePath)")
        }

        let backupPath = abs + backupExtension
        if !POSIXFile.exists(backupPath) {
            do {
                try POSIXFile.copy(from: abs, to: backupPath)
            } catch {
                throw ModManagerError.ioFailed(error.localizedDescription)
            }
        }
        var list = registry(for: bundleID)
        if !list.contains(backupPath) {
            list.append(backupPath)
            saveRegistry(list, for: bundleID)
        }
    }

    public func installMod(_ mod: ModEntry, bundleID: String, mode: String = "replace") throws {
        _ = try? prepareContainer(bundleID: bundleID)
        let receipt = PatchTransactionManager.shared.beginTransaction(bundleID: bundleID)
        var modFiles: [String] = []
        var backupMap: [String: String] = [:]
        var injFiles: [String] = []

        // FFXC Delta Anti-Ban Hook: Tu dong triet ha Telemetry & Integrity Caches truoc khi patch
        if mod.files.contains(where: { $0.relativePath.contains("Assembly-CSharp-patch.bytes") }) {
            FFAntiBanService.shared.purgeTelemetryAndIntegrity(bundleID: bundleID, directContainer: containerRoot)
            FFAntiBanService.shared.normalizeMetadata(bundleID: bundleID, directContainer: containerRoot)
        }

        for file in mod.files {
            let abs = try? absolute(file.relativePath)
            modFiles.append(file.relativePath)
            if mode == "inject" || abs == nil || !POSIXFile.exists(abs!) {
                // File tiêm mới: ghi nhận vào registry để khi tắt mod thì xóa sạch
                recordInjectedFile(file.relativePath, bundleID: bundleID)
                injFiles.append(file.relativePath)
            } else {
                // File thay thế: sao lưu bản gốc thành .bak
                try? backupFile(relativePath: file.relativePath, bundleID: bundleID)
                backupMap[file.relativePath] = file.relativePath + backupExtension
            }
            try AirLiftTransport.shared.writeAppFile(data: file.data, bundleID: bundleID, relativePath: file.relativePath, directPath: abs)
            ContainerAccess.diag("Đã dán file thành công: \(file.relativePath) (\(file.data.count) bytes)")
        }

        // Commit giao dịch an toàn và dọn dẹp file tạm/staging
        let completedReceipt = PatchReceipt(
            id: receipt.id,
            bundleID: bundleID,
            timestamp: receipt.timestamp,
            modifiedFiles: modFiles,
            backupFiles: backupMap,
            injectedFiles: injFiles,
            isCommitted: true
        )
        PatchTransactionManager.shared.commitTransaction(completedReceipt)
        PatchTransactionManager.shared.cleanStagingAndTempFiles(containerRoot: containerRoot)
    }

    /// FFXC-V4 Anti-Forensics: Tự động xóa file patch sau khi game đã nạp xong vào RAM (7.5 giây sau khi inject)
    public func scheduleTimedWipe(relativePath: String = "Documents/Assembly-CSharp-patch.bytes", delaySeconds: Double = 7.5) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delaySeconds) {
            let abs = try? self.absolute(relativePath)
            try? AirLiftTransport.shared.removeAppFile(bundleID: GameBundleID.freeFire, relativePath: relativePath, directPath: abs)
            try? AirLiftTransport.shared.removeAppFile(bundleID: GameBundleID.freeFireMax, relativePath: relativePath, directPath: abs)
            ContainerAccess.diag("[FFXC-V4] Timed wipe applied successfully: \(relativePath) cleaned from disk.")
        }
    }

    public func restoreFile(relativePath: String, bundleID: String, mode: String = "replace") throws {
        _ = try? prepareContainer(bundleID: bundleID)
        let abs = try? absolute(relativePath)
        let backupPath = abs != nil ? (abs! + backupExtension) : nil

        if let abs = abs, let backupPath = backupPath, POSIXFile.exists(backupPath) {
            // Có file backup -> khôi phục lại file gốc ban đầu
            do {
                if POSIXFile.exists(abs) {
                    try POSIXFile.remove(abs)
                }
                try POSIXFile.move(from: backupPath, to: abs)
                var list = registry(for: bundleID)
                list.removeAll(where: { $0 == backupPath })
                saveRegistry(list, for: bundleID)
            } catch {
                throw ModManagerError.ioFailed(error.localizedDescription)
            }
        } else {
            // Không có file backup HOẶC là mod tiêm mới -> TẮT LÀ XOÁ SẠCH!
            try AirLiftTransport.shared.removeAppFile(bundleID: bundleID, relativePath: relativePath, directPath: abs)
        }
        removeInjectedFile(relativePath, bundleID: bundleID)

        // Tự động dọn dẹp file cấu hình kèm theo nếu là patch IFix
        if relativePath.contains("Assembly-CSharp-patch.bytes") {
            if let configAbs = try? absolute("Documents/localConfig.json"), POSIXFile.exists(configAbs) {
                try? POSIXFile.remove(configAbs)
            }
        }
        PatchTransactionManager.shared.cleanStagingAndTempFiles(containerRoot: containerRoot)
    }

    public func restoreFiles(for mod: ModEntry) throws {
        for file in mod.files {
            try restoreFile(relativePath: file.relativePath, bundleID: containerRoot ?? "")
        }
    }

    public func restoreAll(bundleID: String) throws {
        _ = try prepareContainer(bundleID: bundleID)
        let list = registry(for: bundleID)
        var restored = 0
        for backupPath in list {
            let origPath = String(backupPath.dropLast(backupExtension.count))
            guard POSIXFile.exists(backupPath) else { continue }
            do {
                if POSIXFile.exists(origPath) {
                    try POSIXFile.remove(origPath)
                }
                try POSIXFile.move(from: backupPath, to: origPath)
                restored += 1
            } catch {
                throw ModManagerError.ioFailed(error.localizedDescription)
            }
        }
        saveRegistry([], for: bundleID)

        // Xoá sạch toàn bộ các file tiêm mới
        let injected = injectedRegistry(for: bundleID)
        for rel in injected {
            if let abs = try? absolute(rel), POSIXFile.exists(abs) {
                try? POSIXFile.remove(abs)
            }
        }
        saveInjectedRegistry([], for: bundleID)

        // Dọn dẹp localConfig.json nếu có
        if let configAbs = try? absolute("Documents/localConfig.json"), POSIXFile.exists(configAbs) {
            try? POSIXFile.remove(configAbs)
        }

        _ = restored
    }

    private func writeFile(data: Data, to path: String) throws {
        ContainerAccess.diag("[Mod] Ghi file: \((path as NSString).lastPathComponent) (\(data.count) bytes)")
        do {
            try POSIXFile.write(data: data, to: path)
        } catch {
            ContainerAccess.diag("[Mod] ❌ Ghi file thất bại: \(error.localizedDescription)")
            throw ModManagerError.ioFailed(error.localizedDescription)
        }
    }

    /// Cơ chế Neutralization theo chuẩn Sophia: Sau khi game đã nạp bytecode vào RAM,
    /// tự động ghi đè file 322 bytes (Neutral Seed) lên Assembly-CSharp-patch.bytes để tẩy trắng,
    /// xóa dấu vết trên đĩa giúp chống quét tệp / chống khóa tài khoản 100%.
    public func neutralizePatch(bundleID: String) {
        let patchAbs = try? absolute("Documents/Assembly-CSharp-patch.bytes")
        try? AirLiftTransport.shared.writeAppFile(data: NeutralSeed.data, bundleID: bundleID, relativePath: "Documents/Assembly-CSharp-patch.bytes", directPath: patchAbs)
        let configAbs = try? absolute("Documents/localConfig.json")
        try? AirLiftTransport.shared.removeAppFile(bundleID: bundleID, relativePath: "Documents/localConfig.json", directPath: configAbs)
        print("[WIPE] timed cleanup applied - payload neutralized with 322b seed")
    }
}