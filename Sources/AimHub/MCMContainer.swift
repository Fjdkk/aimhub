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
        let setIdentifiers: @convention(c) (Query?, CFArray) -> Void
        let setGroupIdentifiers: @convention(c) (Query?, CFArray) -> Void
        let setFlags: @convention(c) (Query?, UInt64) -> Void
        let setPart: @convention(c) (Query?, UInt64) -> Void
        let setPartDomain: @convention(c) (Query?, UInt64) -> Void
        let getSingleResult: @convention(c) (Query?, UnsafeMutablePointer<ErrorRef?>) -> Object?
        let getLastError: @convention(c) (Query?) -> ErrorRef?
        let iterateResultsSync: @convention(c) (Query?, UnsafeMutablePointer<ErrorRef?>) -> Object?
        let free: @convention(c) (Query?) -> Void
        let objectGetPath: @convention(c) (Object?) -> UnsafeMutablePointer<CChar>?
        let objectGetIdentifier: @convention(c) (Object?) -> UnsafeMutablePointer<CChar>?
        let objectCopy: @convention(c) (Object?) -> Object?
        let copySandboxToken: @convention(c) (Object?) -> UnsafeMutablePointer<CChar>?
        let sandboxExtensionActivate: @convention(c) (Object?, UnsafeMutablePointer<ErrorRef?>) -> Int32
        let objectFree: @convention(c) (Object?) -> Void
        let sandboxExtensionConsume: @convention(c) (UnsafePointer<CChar>?) -> Int32
        let sandboxExtensionRelease: @convention(c) (Int32) -> Int32
        let errorGetPosixErrno: @convention(c) (ErrorRef?) -> Int32
        let errorGetMessage: @convention(c) (ErrorRef?) -> UnsafeMutablePointer<CChar>?
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
            sandboxExtensionConsume: try sym("sandbox_extension_consume"),
            sandboxExtensionRelease: try sym("sandbox_extension_release"),
            errorGetPosixErrno: try sym("container_error_get_posix_errno"),
            errorGetMessage: try sym("container_error_get_message")
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

        let ids: CFArray
        if let identifier = identifier {
            let arr = [bundleID, identifier] as NSArray
            ids = arr as CFArray
        } else {
            let arr = [bundleID] as NSArray
            ids = arr as CFArray
        }
        fns.setIdentifiers(query, ids)
        fns.setFlags(query, 0)
        fns.setPart(query, part)
        fns.setPartDomain(query, 0)

        var err: ErrorRef? = nil
        var obj = fns.getSingleResult(query, &err)

        // Fallback: iterate_results_sync giống app tham chiếu
        if obj == nil {
            obj = fns.iterateResultsSync(query, &err)
        }
        guard let obj = obj else {
            throw MCMError.queryFailed(errorText(err ?? fns.getLastError(query)))
        }
        defer { fns.objectFree(obj) }

        guard let pathPtr = fns.objectGetPath(obj) else {
            throw MCMError.objectFailed(errorText(err))
        }
        let path = String(cString: pathPtr)
        free(pathPtr)

        if activateExtension {
            // Kích hoạt sandbox extension để có quyền ghi vào container
            if let tokenPtr = fns.copySandboxToken(obj) {
                let token = String(cString: tokenPtr)
                free(tokenPtr)
                fns.sandboxExtensionConsume(token)
            } else {
                var actErr: ErrorRef? = nil
                let rc = fns.sandboxExtensionActivate(obj, &actErr)
                if rc != 0 {
                    throw MCMError.activationFailed(fns.errorGetPosixErrno(actErr))
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
        let arr = [bundleID] as NSArray
        fns.setIdentifiers(query, arr as CFArray)
        fns.setFlags(query, 0)
        fns.setPart(query, 0)
        fns.setPartDomain(query, 0)

        var err: ErrorRef? = nil
        guard let obj = fns.getSingleResult(query, &err) else {
            throw MCMError.queryFailed(errorText(err ?? fns.getLastError(query)))
        }
        defer { fns.objectFree(obj) }

        guard let tok = fns.copySandboxToken(obj) else {
            throw MCMError.objectFailed(errorText(err))
        }
        let token = String(cString: tok)
        free(tok)
        return token
    }

    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }
}