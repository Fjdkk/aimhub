import Foundation

public enum AppLauncher {
    public static func openGame(bundleID: String) -> Bool {
        guard let workspace = defaultWorkspace else { return false }
        let openSel = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspace.responds(to: openSel) else { return false }
        _ = workspace.perform(openSel, with: NSString(string: bundleID))
        return true
    }

    // Liệt kê toàn bộ app đã cài (kỹ thuật của app tham chiếu CheatiOS DSW).
    // applicationIsInstalled: trả false khi host chạy với bundle ID daemon hệ
    // thống (com.apple.mobile.MobileHouseArrest), nên phải quét danh sách.
    private static func installedProxies() -> [NSObject] {
        guard let workspace = defaultWorkspace else { return [] }
        let listSel = NSSelectorFromString("allInstalledApplications")
        guard workspace.responds(to: listSel),
              let result = workspace.perform(listSel)?.takeUnretainedValue() as? NSArray else {
            return []
        }
        return result.compactMap { $0 as? NSObject }
    }

    public static func isGameInstalled(bundleID: String) -> Bool {
        for proxy in installedProxies() {
            if let b = proxyBundleID(proxy), b == bundleID {
                return true
            }
        }
        return false
    }

    // Chẩn đoán: liệt kê app có bundle ID chứa "freefire"/"dts" để đối chiếu
    // với bundle ID mà server/ code hardcode.
    public static func debugGameApps() -> [String] {
        var out: [String] = []
        for proxy in installedProxies() {
            guard let b = proxyBundleID(proxy) else { continue }
            let low = b.lowercased()
            if low.contains("freefire") || low.contains("dts") {
                out.append(b)
            }
        }
        return out.sorted()
    }

    // Tìm app khớp bundle ID (prefix) — Free Fire / FF Max có thể khác hậu tố
    // theo vùng. Trả về dataContainerURL của app tìm thấy.
    public static func containerPath(bundleID: String) -> String? {
        for proxy in installedProxies() {
            guard let b = proxyBundleID(proxy), b == bundleID else { continue }
            if let url = proxy.value(forKey: "dataContainerURL") as? URL {
                return url.path
            }
        }
        return nil
    }

    private static func proxyBundleID(_ proxy: NSObject) -> String? {
        if let v = proxy.value(forKey: "applicationIdentifier") as? String {
            return v
        }
        if let v = proxy.value(forKey: "bundleIdentifier") as? String {
            return v
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