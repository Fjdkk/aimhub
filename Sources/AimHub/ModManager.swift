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

public enum ModManagerError: Error, CustomStringConvertible {
    case containerUnavailable
    case noBackup
    case ioFailed(String)

    public var description: String {
        switch self {
        case .containerUnavailable:
            return "Không truy cập được container trò chơi"
        case .noBackup:
            return "Không tìm thấy bản backup"
        case .ioFailed(let m):
            return "Lỗi ghi file: \(m)"
        }
    }
}

/// Thao tác file bằng POSIX trực tiếp (open/write/rename/unlink/mkdir).
/// Foundation/FileManager tự kiểm tra sandbox theo bundle ID hiện tại và
/// có thể chặn truy cập container của app khác dù sandbox extension đã được
/// consume. POSIX nói chuyện thẳng với kernel, chỉ kiểm tra extension đã consume.
enum POSIXFileError: Error, CustomStringConvertible {
    case io(String)
    var description: String {
        switch self {
        case .io(let m): return m
        }
    }
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

        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXFileError.io("open \(path) thất bại: \(errnoMessage())") }
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
    }
}

public final class ModManager {
    public static let shared = ModManager()

    private let backupExtension = ".bak"
    private let registryKey = "aimhub.backup.registry"

    private var containerRoot: String?

    public func prepareContainer(bundleID: String) throws -> String {
        let path = try ContainerAccess.shared.gameContainerPath(bundleID: bundleID)
        guard POSIXFile.isDirectory(path) else {
            throw ModManagerError.containerUnavailable
        }
        containerRoot = path
        return path
    }

    private func absolute(_ relativePath: String) throws -> String {
        guard let root = containerRoot else { throw ModManagerError.containerUnavailable }
        let joined = (root as NSString).appendingPathComponent(relativePath)
        return (joined as NSString).standardizingPath
    }

    private func registry() -> [String] {
        UserDefaults.standard.stringArray(forKey: registryKey) ?? []
    }

    private func saveRegistry(_ list: [String]) {
        UserDefaults.standard.set(list, forKey: registryKey)
    }

    public func hasBackup(relativePath: String) -> Bool {
        guard let abs = try? absolute(relativePath) else { return false }
        return POSIXFile.exists(abs + backupExtension)
    }

    public func backupFile(relativePath: String) throws {
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
        var list = registry()
        if !list.contains(backupPath) {
            list.append(backupPath)
            saveRegistry(list)
        }
    }

    public func installMod(_ mod: ModEntry, bundleID: String) throws {
        _ = try prepareContainer(bundleID: bundleID)
        for file in mod.files {
            try backupFile(relativePath: file.relativePath)
            let abs = try absolute(file.relativePath)
            try writeFile(data: file.data, to: abs)
        }
    }

    public func restoreFiles(for mod: ModEntry) throws {
        for file in mod.files {
            let abs = try absolute(file.relativePath)
            let backupPath = abs + backupExtension
            guard POSIXFile.exists(backupPath) else { throw ModManagerError.noBackup }
            do {
                try POSIXFile.remove(abs)
                try POSIXFile.move(from: backupPath, to: abs)
            } catch {
                throw ModManagerError.ioFailed(error.localizedDescription)
            }
        }
    }

    public func restoreAll(bundleID: String) throws {
        _ = try prepareContainer(bundleID: bundleID)
        let list = registry()
        var restored = 0
        for backupPath in list {
            let origPath = String(backupPath.dropLast(backupExtension.count))
            guard POSIXFile.exists(backupPath) else { continue }
            do {
                try POSIXFile.remove(origPath)
                try POSIXFile.move(from: backupPath, to: origPath)
                restored += 1
            } catch {
                throw ModManagerError.ioFailed(error.localizedDescription)
            }
        }
        saveRegistry([])
        _ = restored
    }

    private func writeFile(data: Data, to path: String) throws {
        do {
            try POSIXFile.write(data: data, to: path)
        } catch {
            throw ModManagerError.ioFailed(error.localizedDescription)
        }
    }
}