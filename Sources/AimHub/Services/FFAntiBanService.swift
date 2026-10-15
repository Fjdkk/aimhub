import Foundation
import Combine
import Darwin

/// FFAntiBanService - He thong Anti-Ban da tang chuan kien truc Delta Client 1.6.5
/// Nhiem vu:
/// 1/3: Purge & Lock 17 thu muc telemetry, 11 cache folder va 9 file contentcache hash
/// 2/3: Dong bo Container Metadata Timestamp voi .com.apple.mobile_container_manager.metadata.plist
/// 3/3: Deploy Patch Assembly-CSharp-patch.bytes + localConfig.json an toan, don sach dau vet loader
public final class FFAntiBanService: ObservableObject {
    public static let shared = FFAntiBanService()

    // MARK: - Published States for SwiftUI
    @Published public var isAntiBanActive: Bool = false
    @Published public var isActivating: Bool = false
    @Published public var currentStepText: String = ""
    @Published public var progressValue: Double = 0.0
    @Published public var lastError: String? = nil
    @Published public var logs: [String] = []

    // MARK: - Telemetry Targets (Boc tach truc tiep tu Mach-O Delta 1.6.5)
    private let telemetryFolders: [String] = [
        "Documents/report",
        "Documents/analytics",
        "Documents/crash_dump",
        "Documents/crash",
        "Documents/beacon",
        "Documents/feedback",
        "Documents/GCloud",
        "Documents/MidasLog",
        "Documents/shadow_tracker",
        "Documents/tencent_tdid",
        "Documents/anti_cheat_logs",
        "Documents/vng_log",
        "Documents/msdk_log",
        "Documents/garena_log",
        "Documents/gvoice",
        "Documents/dp_log",
        "Documents/oss_log",
        "Documents/upload",
        "Documents/pending_reports",
        "Documents/com.tencent.bugly",
        "Documents/bugly",
        "Documents/APLog",
        "Documents/tdlog",
        "Documents/tlog",
        "Documents/xlog",
        "Documents/log"
    ]

    private let cacheFolders: [String] = [
        "tmp",
        "Library/Caches/Analytics",
        "Library/Caches/CrashReporter",
        "Library/Caches/com.crashlytics.data",
        "Library/Caches/crashes",
        "Library/Caches/GCloud",
        "Library/Caches/GVoice",
        "Library/Caches/com.google.firebase",
        "Library/Caches/com.appsflyer",
        "Library/Caches/adjust-sdk",
        "Library/Caches/bugly",
        "Library/Caches/com.tencent.bugly",
        "Library/Caches/Snapshots",
        "Library/Cookies",
        "Library/WebKit"
    ]

    private let integrityFiles: [String] = [
        "Documents/contentcache/res_version.hash",
        "Documents/contentcache/file_hash.bin",
        "Documents/contentcache/verify_cache.dat",
        "Documents/contentcache/crc_cache.bin",
        "Documents/contentcache/asset_verify.db",
        "Documents/contentcache/patch_verify.dat",
        "Documents/contentcache/resource_manifest.json",
        "Documents/contentcache/checksum.bin",
        "Documents/contentcache/integrity_db.sqlite"
    ]

    private let markerFiles: [String] = [
        ".ffxc_live",
        ".ffxc_runtime",
        "athena_config.json"
    ]

    private init() {
        self.isAntiBanActive = UserDefaults.standard.bool(forKey: "aimhub_antiban_active")
    }

    private func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.logs.append(logLine)
            ContainerAccess.diag("[FFAntiBan] \(message)")
        }
    }

    private func updateStep(_ text: String, progress: Double) {
        DispatchQueue.main.async {
            self.currentStepText = text
            self.progressValue = progress
        }
    }

    // MARK: - Main Workflow: 3 Buoc Anti-Ban Chuan Delta 1.6.5

    public func activateAntiBan(
        bundleID: String,
        patchData: Data,
        localConfigData: Data,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            self.isActivating = true
            self.lastError = nil
            self.updateStep("Khoi tao phong tuyen Anti-Ban...", progress: 0.1)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let directContainer = try? ContainerAccess.shared.gameContainerPath(bundleID: bundleID)

                // 1/3: Purge & Lock Telemetry & Hash
                self.updateStep("Buoc 1/3: Triet ha Telemetry & Integrity Caches...", progress: 0.35)
                self.appendLog("Buoc 1/3: Xoa 17 thu muc telemetry & 11 thu muc cache...")
                self.purgeTelemetryAndIntegrity(bundleID: bundleID, directContainer: directContainer)
                self.appendLog("Buoc 1/3: Hoan tat lam sach he thong bao cao gian lan.")

                // 2/3: Dong bo Metadata Container
                self.updateStep("Buoc 2/3: Chuan hoa Container Metadata Timestamp...", progress: 0.70)
                self.appendLog("Buoc 2/3: Dong bo ngay sua doi khop voi Container Metadata ban dau...")
                self.normalizeMetadata(bundleID: bundleID, directContainer: directContainer)
                self.appendLog("Buoc 2/3: Hoan tat chuan hoa sandbox container.")

                // 3/3: Deploy Clean Patch & Clean Loader
                self.updateStep("Buoc 3/3: Nap Patch sach & Triet tieu dau vet loader...", progress: 0.95)
                self.appendLog("Buoc 3/3: Ghi Assembly-CSharp-patch.bytes va localConfig.json...")
                try self.deployCleanPatch(
                    bundleID: bundleID,
                    patchData: patchData,
                    localConfigData: localConfigData,
                    directContainer: directContainer
                )
                self.appendLog("Buoc 3/3: Nap patch thanh cong. Da xoa toan bo dau vet loader.")

                DispatchQueue.main.async {
                    self.isActivating = false
                    self.isAntiBanActive = true
                    self.progressValue = 1.0
                    self.currentStepText = "Anti-Ban LIVE (Delta Isolation Engine)"
                    UserDefaults.standard.set(true, forKey: "aimhub_antiban_active")
                    self.appendLog("SAN SANG: Phong tuyen Anti-Ban da kich hoat. Nguoi dung co the vao game!")
                    completion(.success(()))
                }

            } catch {
                DispatchQueue.main.async {
                    self.isActivating = false
                    self.isAntiBanActive = false
                    self.progressValue = 0.0
                    self.lastError = error.localizedDescription
                    self.currentStepText = "Loi kich hoat Anti-Ban"
                    self.appendLog("THAT BAI: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Subroutines

    public func purgeTelemetryAndIntegrity(bundleID: String, directContainer: String?) {
        for rel in telemetryFolders {
            purgeTarget(relPath: rel, bundleID: bundleID, directContainer: directContainer, lockFolder: true)
        }
        for rel in cacheFolders {
            purgeTarget(relPath: rel, bundleID: bundleID, directContainer: directContainer, lockFolder: false)
        }
        for rel in integrityFiles {
            purgeTarget(relPath: rel, bundleID: bundleID, directContainer: directContainer, lockFolder: false)
        }
    }

    public func purgeTarget(relPath: String, bundleID: String, directContainer: String?, lockFolder: Bool) {
        if let root = directContainer, !root.contains("AirLift-") {
            let fullPath = (root as NSString).appendingPathComponent(relPath)
            if POSIXFile.exists(fullPath) {
                try? POSIXFile.remove(fullPath)
                appendLog("  [POSIX] Da xoa: \(relPath)")
            }
            if lockFolder {
                try? POSIXFile.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
                chmod(fullPath, S_IRUSR | S_IRGRP | S_IROTH)
            }
        } else if AirLiftTransport.shared.isAvailable {
            try? AirLiftTransport.shared.removeAppFile(bundleID: bundleID, relativePath: relPath)
        }
    }

    public func normalizeMetadata(bundleID: String, directContainer: String?) {
        guard let root = directContainer, !root.contains("AirLift-") else { return }
        let metaPath = (root as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        let docsPath = (root as NSString).appendingPathComponent("Documents")

        var refDate = Date()
        if let attrs = try? FileManager.default.attributesOfItem(atPath: metaPath),
           let cDate = attrs[.creationDate] as? Date {
            refDate = cDate
            appendLog("  -> Thoi gian metadata goc: \(refDate)")
        }

        if FileManager.default.fileExists(atPath: docsPath) {
            try? FileManager.default.setAttributes([
                .creationDate: refDate,
                .modificationDate: refDate
            ], ofItemAtPath: docsPath)
        }
    }

    private func deployCleanPatch(
        bundleID: String,
        patchData: Data,
        localConfigData: Data,
        directContainer: String?
    ) throws {
        let patchRel = "Documents/Assembly-CSharp-patch.bytes"
        let backupRel = "Documents/Assembly-CSharp-patch.bytes.bak"
        let configRel = "Documents/localConfig.json"

        if let root = directContainer, !root.contains("AirLift-") {
            let patchFull = (root as NSString).appendingPathComponent(patchRel)
            let backupFull = (root as NSString).appendingPathComponent(backupRel)
            let docsFull = (root as NSString).appendingPathComponent("Documents")

            try? POSIXFile.createDirectory(atPath: docsFull, withIntermediateDirectories: true)

            if POSIXFile.exists(patchFull) && !POSIXFile.exists(backupFull) {
                try? POSIXFile.copy(from: patchFull, to: backupFull)
                appendLog("  -> Da tao ban sao luu: .bak")
            }

            try POSIXFile.write(data: patchData, to: patchFull)
            try POSIXFile.write(data: localConfigData, to: (root as NSString).appendingPathComponent(configRel))

            for marker in markerFiles {
                let mFull = (docsFull as NSString).appendingPathComponent(marker)
                if POSIXFile.exists(mFull) {
                    try? POSIXFile.remove(mFull)
                    appendLog("  -> Da xoa marker: \(marker)")
                }
            }
        } else {
            try AirLiftTransport.shared.writeAppFile(data: patchData, bundleID: bundleID, relativePath: patchRel)
            try AirLiftTransport.shared.writeAppFile(data: localConfigData, bundleID: bundleID, relativePath: configRel)

            for marker in markerFiles {
                let mRel = "Documents/\(marker)"
                try? AirLiftTransport.shared.removeAppFile(bundleID: bundleID, relativePath: mRel)
            }
        }
    }

    // MARK: - Restore & Wipe Session Data

    public func restoreOriginal(bundleID: String) throws {
        let directContainer = try? ContainerAccess.shared.gameContainerPath(bundleID: bundleID)
        let patchRel = "Documents/Assembly-CSharp-patch.bytes"
        let backupRel = "Documents/Assembly-CSharp-patch.bytes.bak"
        let configRel = "Documents/localConfig.json"

        if let root = directContainer, !root.contains("AirLift-") {
            let patchFull = (root as NSString).appendingPathComponent(patchRel)
            let backupFull = (root as NSString).appendingPathComponent(backupRel)
            let configFull = (root as NSString).appendingPathComponent(configRel)

            try? POSIXFile.remove(patchFull)
            try? POSIXFile.remove(configFull)

            if POSIXFile.exists(backupFull) {
                try? POSIXFile.move(from: backupFull, to: patchFull)
                appendLog("Da khoi phuc Assembly-CSharp-patch.bytes tu .bak")
            }
        } else {
            try? AirLiftTransport.shared.removeAppFile(bundleID: bundleID, relativePath: patchRel)
            try? AirLiftTransport.shared.removeAppFile(bundleID: bundleID, relativePath: configRel)
        }

        DispatchQueue.main.async {
            self.isAntiBanActive = false
            self.progressValue = 0.0
            self.currentStepText = "Da khoi phuc nguyen ban"
            UserDefaults.standard.set(false, forKey: "aimhub_antiban_active")
        }
    }

    public func wipeSessionData(bundleID: String) {
        let directContainer = try? ContainerAccess.shared.gameContainerPath(bundleID: bundleID)
        let sessionTargets = [
            "Library/Cookies/Cookies.binarycookies",
            "Library/Caches/garena",
            "Library/Caches/com.garena",
            "Library/Caches/com.facebook.sdk",
            "Library/Caches/com.google.gmp",
            "Library/WebKit/WebsiteData"
        ]

        for target in sessionTargets {
            purgeTarget(relPath: target, bundleID: bundleID, directContainer: directContainer, lockFolder: false)
        }
        appendLog("Da xoa sach session token & cookies cu de game nhan thiet bi sach 100%.")
    }
}
