import Foundation
import Darwin

public enum MCMError: Error, CustomStringConvertible {
    case dlopenFailed
    case symbolNotFound(String)
    case queryFailed(String)
    case objectFailed(String)
    case activationFailed(Int32)

    public var description: String {
        switch self {
        case .dlopenFailed:
            return "Không thể nạp libsystem_containermanager.dylib"
        case .symbolNotFound(let s):
            return "Không tìm thấy hàm: \(s)"
        case .queryFailed(let m):
            return "Truy vấn container thất bại: \(m)"
        case .objectFailed(let m):
            return "Container object thất bại: \(m)"
        case .activationFailed(let e):
            return "Kích hoạt sandbox extension thất bại (errno=\(e))"
        }
    }

    public var errorDescription: String? { description }
}

public enum MCMContainerClass: UInt32 {
    case system = 1
    case data = 2
    case pluginData = 3
    case bundle = 4
    case group = 5
    case systemGroup = 6
    case temp = 7
    case migrationTest = 8
}

public final class MCMContainer {
    public typealias Query = OpaquePointer
    public typealias Object = OpaquePointer
    public typealias ErrorRef = OpaquePointer

    public static let shared: MCMContainer? = {
        try? MCMContainer()
    }()

    public var isLoaded: Bool {
        handle != nil && fns != nil
    }

    private let handle: UnsafeMutableRawPointer?
    private let fns: Fns?

    private struct Fns {
        let create: @convention(c) () -> Query?
        let setClass: @convention(c) (Query?, UInt64) -> Void
        let setIdentifiers: @convention(c) (Query?, OpaquePointer?) -> Void
        let setGroupIdentifiers: @convention(c) (Query?, OpaquePointer?) -> Void
        let setFlags: @convention(c) (Query?, UInt64) -> Void
        let setPart: @convention(c) (Query?, UInt64) -> Void
        let setPartDomain: @convention(c) (Query?, UnsafePointer<CChar>?) -> Void
        let getSingleResult: @convention(c) (Query?) -> Object?
        let getLastError: @convention(c) (Query?) -> ErrorRef?
        let iterateResultsSync: @convention(c) (Query?, @convention(block) (Object?) -> Bool) -> Bool
        let free: @convention(c) (Query?) -> Void
        let objectGetPath: @convention(c) (Object?) -> UnsafeMutablePointer<CChar>?
        let objectGetIdentifier: @convention(c) (Object?) -> UnsafeMutablePointer<CChar>?
        let objectCopy: @convention(c) (Object?) -> Object?
        let copySandboxToken: @convention(c) (Object?) -> UnsafeMutablePointer<CChar>?
        let sandboxExtensionActivate: @convention(c) (Object?, Bool) -> Bool
        let objectFree: @convention(c) (Object?) -> Void
        let sandboxExtensionConsume: @convention(c) (UnsafePointer<CChar>?) -> Int64
        let sandboxExtensionRelease: @convention(c) (Int64) -> Int32
        let errorGetPosixErrno: @convention(c) (ErrorRef?) -> Int32
        let errorGetMessage: @convention(c) (ErrorRef?) -> UnsafeMutablePointer<CChar>?
        let xpcStringCreate: @convention(c) (UnsafePointer<CChar>?) -> OpaquePointer?
        let xpcRelease: @convention(c) (OpaquePointer?) -> Void
    }

    public init() throws {
        guard let h = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_LAZY) else {
            throw MCMError.dlopenFailed
        }
        handle = h

        func sym<T>(_ name: String) throws -> T {
            guard let p = dlsym(h, name) else { throw MCMError.symbolNotFound(name) }
            return unsafeBitCast(p, to: T.self)
        }
        func symGlobal<T>(_ name: String) throws -> T {
            guard let p = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { throw MCMError.symbolNotFound(name) }
            return unsafeBitCast(p, to: T.self)
        }

        let resolved = Fns(
            create: try sym("container_query_create"),
            setClass: try sym("container_query_set_class"),
            setIdentifiers: try sym("container_query_set_identifiers"),
            setGroupIdentifiers: try sym("container_query_set_group_identifiers"),
            setFlags: try sym("container_query_operation_set_flags"),
            setPart: try sym("container_query_operation_set_part"),
            setPartDomain: try sym("container_query_operation_set_part_domain"),
            getSingleResult: try sym("container_query_get_single_result"),
            getLastError: try sym("container_query_get_last_error"),
            iterateResultsSync: try sym("container_query_iterate_results_sync"),
            free: try sym("container_query_free"),
            objectGetPath: try sym("container_object_get_path"),
            objectGetIdentifier: try sym("container_object_get_identifier"),
            objectCopy: try sym("container_object_copy"),
            copySandboxToken: try sym("container_copy_sandbox_token"),
            sandboxExtensionActivate: try sym("container_object_sandbox_extension_activate"),
            objectFree: try sym("container_object_free"),
            sandboxExtensionConsume: try symGlobal("sandbox_extension_consume"),
            sandboxExtensionRelease: try symGlobal("sandbox_extension_release"),
            errorGetPosixErrno: try sym("container_error_get_posix_errno"),
            errorGetMessage: try sym("container_error_get_message"),
            xpcStringCreate: try symGlobal("xpc_string_create"),
            xpcRelease: try symGlobal("xpc_release")
        )
        fns = resolved
    }

    private func errorText(_ e: ErrorRef?) -> String {
        guard let e = e else { return "unknown" }
        guard let fns = fns else { return "errno unknown" }
        if let msg = fns.errorGetMessage(e) {
            let s = String(cString: msg)
            free(msg)
            return s
        }
        return "errno=\(fns.errorGetPosixErrno(e))"
    }

    /// Phiên bản AN TOÀN của containerPath: chỉ dùng các symbol MCM đã xác
    /// minh ổn định (create → set_class → set_identifiers → set_flags →
    /// set_part → get_single_result). KHÔNG gọi set_part_domain / dùng
    /// get_single_result(query) với signature (query, err).
    public func containerPathBasic(
        forBundleID bundleID: String,
        identifier: String? = nil,
        cls: MCMContainerClass = .data,
        part: UInt64 = 0,
        activateExtension: Bool = true
    ) throws -> String {
        guard let fns = fns else { throw MCMError.dlopenFailed }

        guard let query = fns.create() else { throw MCMError.queryFailed("create") }
        defer { fns.free(query) }

        fns.setClass(query, UInt64(cls.rawValue))

        let id = identifier ?? bundleID
        guard let xpcID = fns.xpcStringCreate(id) else {
            throw MCMError.queryFailed("xpc_string_create")
        }
        defer { fns.xpcRelease(xpcID) }

        fns.setIdentifiers(query, xpcID)
        fns.setFlags(query, 0x900000000)
        fns.setPart(query, part)

        guard let obj = fns.getSingleResult(query) else {
            throw MCMError.queryFailed(errorText(fns.getLastError(query)))
        }
        defer { fns.objectFree(obj) }

        guard let pathPtr = fns.objectGetPath(obj) else {
            throw MCMError.objectFailed("no path")
        }
        let path = String(cString: pathPtr)
        free(pathPtr)

        if activateExtension {
            if let tokenPtr = fns.copySandboxToken(obj) {
                let token = String(cString: tokenPtr)
                free(tokenPtr)
                let h = fns.sandboxExtensionConsume(token)
                _ = h
            } else {
                let ok = fns.sandboxExtensionActivate(obj, false)
                if !ok {
                    throw MCMError.activationFailed(0)
                }
            }
        }

        return path
    }

    public func containerPath(
        forBundleID bundleID: String,
        identifier: String? = nil,
        cls: MCMContainerClass = .data,
        part: UInt64 = 0,
        activateExtension: Bool = true
    ) throws -> String {
        guard let fns = fns else { throw MCMError.dlopenFailed }

        guard let query = fns.create() else { throw MCMError.queryFailed("create") }
        defer { fns.free(query) }

        fns.setClass(query, UInt64(cls.rawValue))

        let id = identifier ?? bundleID
        guard let xpcID = fns.xpcStringCreate(id) else {
            throw MCMError.queryFailed("xpc_string_create")
        }
        defer { fns.xpcRelease(xpcID) }

        fns.setIdentifiers(query, xpcID)
        fns.setFlags(query, 0x900000000)
        fns.setPart(query, part)

        let obj = fns.getSingleResult(query)

        // Fallback: iterate_results_sync giống app tham chiếu. Object chỉ hợp
        // lệnh trong lúc block chạy → phải lấy path + token ngay trong block.
        if obj == nil {
            var iteratedPath: String? = nil
            let rc = fns.iterateResultsSync(query) { candidate in
                guard iteratedPath == nil, let candidate = candidate else { return true }
                guard let p = fns.objectGetPath(candidate) else { return true }
                iteratedPath = String(cString: p)
                free(p)
                if activateExtension, let tokenPtr = fns.copySandboxToken(candidate) {
                    let token = String(cString: tokenPtr)
                    free(tokenPtr)
                    let h = fns.sandboxExtensionConsume(token)
                    _ = h
                }
                return true
            }
            if !rc {
                throw MCMError.queryFailed("iterate denied \(errorText(fns.getLastError(query)))")
            }
            guard let path = iteratedPath else {
                throw MCMError.queryFailed(errorText(fns.getLastError(query)))
            }
            return path
        }
        defer { fns.objectFree(obj) }

        guard let pathPtr = fns.objectGetPath(obj) else {
            throw MCMError.objectFailed("no path")
        }
        let path = String(cString: pathPtr)
        free(pathPtr)

        if activateExtension {
            // Kích hoạt sandbox extension để có quyền ghi vào container
            if let tokenPtr = fns.copySandboxToken(obj) {
                let token = String(cString: tokenPtr)
                free(tokenPtr)
                let h = fns.sandboxExtensionConsume(token)
                _ = h
            } else {
                let ok = fns.sandboxExtensionActivate(obj, false)
                if !ok {
                    throw MCMError.activationFailed(0)
                }
            }
        }

        return path
    }

    public func sandboxToken(forBundleID bundleID: String) throws -> String {
        guard let fns = fns else { throw MCMError.dlopenFailed }

        guard let query = fns.create() else { throw MCMError.queryFailed("create") }
        defer { fns.free(query) }

        fns.setClass(query, UInt64(MCMContainerClass.data.rawValue))
        guard let xpcID = fns.xpcStringCreate(bundleID) else {
            throw MCMError.queryFailed("xpc_string_create")
        }
        defer { fns.xpcRelease(xpcID) }
        fns.setIdentifiers(query, xpcID)
        fns.setFlags(query, 0x900000000)
        fns.setPart(query, 0)

        guard let obj = fns.getSingleResult(query) else {
            throw MCMError.queryFailed(errorText(fns.getLastError(query)))
        }
        defer { fns.objectFree(obj) }

        guard let tok = fns.copySandboxToken(obj) else {
            throw MCMError.objectFailed("no token")
        }
        let token = String(cString: tok)
        free(tok)
        return token
    }

    /// Quét toàn bộ data container bằng MCM iterate_results_sync rồi khớp
    /// identifier — phương án dự phòng khi truy vấn theo tên thất bại
    /// (kỹ thuật của app tham chiếu: container_object_get_identifier).
    public func containerPathByIterating(
        forBundleID bundleID: String,
        cls: MCMContainerClass = .data
    ) throws -> String? {
        guard let fns = fns else { throw MCMError.dlopenFailed }

        guard let query = fns.create() else { throw MCMError.queryFailed("create") }
        defer { fns.free(query) }

        fns.setClass(query, UInt64(cls.rawValue))
        fns.setFlags(query, 0x100000000)
        fns.setPart(query, 0)

        var foundPath: String? = nil
        let rc = fns.iterateResultsSync(query) { current in
            guard let current = current, foundPath == nil else { return true }
            let ident: String? = {
                guard let p = fns.objectGetIdentifier(current) else { return nil }
                let s = String(cString: p)
                free(p)
                return s
            }()
            let path: String? = {
                guard let p = fns.objectGetPath(current) else { return nil }
                let s = String(cString: p)
                free(p)
                return s
            }()
            if ident == bundleID, let path = path {
                // Kích hoạt quyền truy cập container
                if let tokenPtr = fns.copySandboxToken(current) {
                    let token = String(cString: tokenPtr)
                    free(tokenPtr)
                    let h = fns.sandboxExtensionConsume(token)
                    _ = h
                }
                foundPath = path
                return false
            }
            return true
        }
        if !rc {
            throw MCMError.queryFailed("iterate denied \(errorText(fns.getLastError(query)))")
        }
        return foundPath
    }

    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }
}