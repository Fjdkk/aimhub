import Foundation

public enum AppLauncher {
    public static func openGame(bundleID: String) -> Bool {
        guard let workspace = defaultWorkspace else { return false }
        let openSel = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspace.responds(to: openSel) else { return false }
        _ = workspace.perform(openSel, with: NSString(string: bundleID))
        return true
    }

    public static func isGameInstalled(bundleID: String) -> Bool {
        guard let workspace = defaultWorkspace else { return false }
        // Liệt kê tất cả app đã cài (giống app tham chiếu CheatiOS DSW).
        // applicationIsInstalled: trả false khi host chạy với bundle ID
        // daemon hệ thống (com.apple.mobile.MobileHouseArrest).
        let listSel = NSSelectorFromString("allInstalledApplications")
        guard workspace.responds(to: listSel),
              let result = workspace.perform(listSel)?.takeUnretainedValue() as? NSArray else {
            return false
        }
        for case let proxy as NSObject in result {
            if let proxyBundle = proxy.value(forKey: "bundleIdentifier") as? String,
               proxyBundle == bundleID {
                return true
            }
            if let proxyBundle = proxy.value(forKey: "applicationIdentifier") as? String,
               proxyBundle == bundleID {
                return true
            }
        }
        return false
    }

    public static func containerPath(bundleID: String) -> String? {
        guard let workspace = defaultWorkspace else { return nil }
        let listSel = NSSelectorFromString("allInstalledApplications")
        guard workspace.responds(to: listSel),
              let result = workspace.perform(listSel)?.takeUnretainedValue() as? NSArray else {
            return nil
        }
        for case let proxy as NSObject in result {
            let proxyBundle = proxy.value(forKey: "bundleIdentifier") as? String
                ?? proxy.value(forKey: "applicationIdentifier") as? String
            guard proxyBundle == bundleID else { continue }
            if let url = proxy.value(forKey: "dataContainerURL") as? URL {
                return url.path
            }
        }
        return nil
    }

    private static var defaultWorkspace: NSObject? {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return nil
        }
        let sel = NSSelectorFromString("defaultWorkspace")
        guard cls.responds(to: sel),
              let workspace = cls.perform(sel)?.takeUnretainedValue() as? NSObject else {
            return nil
        }
        return workspace
    }
}