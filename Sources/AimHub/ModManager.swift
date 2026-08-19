import Foundation

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

public final class ModManager {
    public static let shared = ModManager()

    private let fm = FileManager.default
    private let backupExtension = ".bak"
    private let registryKey = "aimhub.backup.registry"

    private var containerRoot: String?

    public func prepareContainer(bundleID: String) throws -> String {
        let path = try ContainerAccess.shared.gameContainerPath(bundleID: bundleID)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
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
        return fm.fileExists(atPath: abs + backupExtension)
    }

    public func backupFile(relativePath: String) throws {
        let abs = try absolute(relativePath)
        guard fm.fileExists(atPath: abs) else { throw ModManagerError.ioFailed("Không tồn tại: \(relativePath)") }

        let backupPath = abs + backupExtension
        if !fm.fileExists(atPath: backupPath) {
            do {
                try fm.copyItem(atPath: abs, toPath: backupPath)
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
            guard fm.fileExists(atPath: backupPath) else { throw ModManagerError.noBackup }
            do {
                try fm.removeItem(atPath: abs)
                try fm.moveItem(atPath: backupPath, toPath: abs)
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
            guard fm.fileExists(atPath: backupPath) else { continue }
            do {
                try fm.removeItem(atPath: origPath)
                try fm.moveItem(atPath: backupPath, toPath: origPath)
                restored += 1
            } catch {
                throw ModManagerError.ioFailed(error.localizedDescription)
            }
        }
        saveRegistry([])
        _ = restored
    }

    private func writeFile(data: Data, to path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: dir) {
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            } catch {
                throw ModManagerError.ioFailed(error.localizedDescription)
            }
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            throw ModManagerError.ioFailed(error.localizedDescription)
        }
    }
}