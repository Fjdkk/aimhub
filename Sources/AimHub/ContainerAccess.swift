import Foundation

public enum GameBundleID {
    public static let freeFire = "com.dts.freefireth"
    public static let freeFireMax = "com.dts.freefiremax"
    public static let houseArrest = "com.apple.mobile.MobileHouseArrest"
}

public final class ContainerAccess {
    public static let shared = ContainerAccess()

    private let mcm: MCMContainer?

    public init() {
        mcm = MCMContainer.shared
    }

    public var isAvailable: Bool {
        mcm?.isLoaded ?? false
    }

    public func gameContainerPath(bundleID: String) throws -> String {
        guard let mcm = mcm else { throw MCMError.dlopenFailed }
        return try mcm.containerPath(forBundleID: bundleID, cls: .data, part: 0)
    }

    public func gameSandboxToken(bundleID: String) throws -> String {
        guard let mcm = mcm else { throw MCMError.dlopenFailed }
        return try mcm.sandboxToken(forBundleID: bundleID)
    }
}