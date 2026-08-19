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
        let infoSel = NSSelectorFromString("applicationIsInstalled:")
        guard workspace.responds(to: infoSel),
              let result = workspace.perform(infoSel, with: NSString(string: bundleID)),
              let number = result.takeUnretainedValue() as? NSNumber else {
            return false
        }
        return number.boolValue
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