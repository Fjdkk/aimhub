import Foundation
import NetworkExtension
import Combine
import UIKit

@MainActor
public final class DNSAntiManager: ObservableObject {
    public static let shared = DNSAntiManager()

    public let profileID = "62aaee"
    public let serverURLString = "https://ios.dns.nextdns.io/62aaee"
    public let profileDisplayName = "AimHub"

    @Published public var isProtected: Bool = false
    @Published public var isChecking: Bool = false
    @Published public var showInstallFallbackAlert: Bool = false

    private var pollTimer: Timer?
    private var permissionPollTask: Task<Void, Never>?

    private init() {
        self.isProtected = UserDefaults.standard.bool(forKey: "aimhub_dns_anti_enabled")
        setupNotificationObservers()
        Task {
            await verifyStatus()
        }
    }

    private func setupNotificationObservers() {
        // Lắng nghe khi cấu hình DNS trong iOS thay đổi
        NotificationCenter.default.addObserver(
            forName: .NEDNSSettingsConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }

        // Lắng nghe khi người dùng quay lại app (sau khi bấm Cho phép popup iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }
    }

    // MARK: - Yêu cầu cấp quyền & Tự động bật DNS AimHub

    public func requestPermission() {
        guard !isChecking else { return }
        isChecking = true

        Task {
            await startProtection()
            // Bắt đầu quét nhanh trong 8 giây để nhận diện ngay khi user bấm "Cho phép" trên popup iOS
            startPermissionCheckPolling()
        }
    }

    private func startPermissionCheckPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task {
            for _ in 0..<16 { // 16 lần x 0.5s = 8 giây
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { break }
                let active = await checkManagerIsEnabled()
                if active {
                    self.isProtected = true
                    self.isChecking = false
                    UserDefaults.standard.set(true, forKey: "aimhub_dns_anti_enabled")
                    break
                }
            }
            self.isChecking = false
        }
    }

    private func checkManagerIsEnabled() async -> Bool {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            return manager.isEnabled
        } catch {
            return false
        }
    }

    // MARK: - Bật DNS Anti (chuẩn NextDNS: NEDNSSettingsManager + NEOnDemandRuleConnect)

    public func startProtection() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()

            let dohSettings = NEDNSOverHTTPSSettings(servers: ["45.90.28.0", "45.90.30.0", "2a07:a8c0::", "2a07:a8c1::"])
            dohSettings.serverURL = URL(string: serverURLString)
            manager.dnsSettings = dohSettings
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            manager.localizedDescription = profileDisplayName // Chỉ ghi đúng chữ "AimHub"

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()

            if manager.isEnabled {
                self.isProtected = true
                UserDefaults.standard.set(true, forKey: "aimhub_dns_anti_enabled")
            }
        } catch {
            print("[DNSAnti] DNS settings failed: \(error)")
        }
    }

    // MARK: - Tắt DNS Anti

    public func stopProtection() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()

            manager.onDemandRules = [NEOnDemandRuleDisconnect()]
            try await manager.saveToPreferences()
            self.isProtected = false
            UserDefaults.standard.set(false, forKey: "aimhub_dns_anti_enabled")
        } catch {
            print("[DNSAnti] Failed to disconnect DNS: \(error)")
        }
    }

    public func setProtection(enabled: Bool) {
        if enabled {
            requestPermission()
        } else {
            Task { await stopProtection() }
        }
    }

    public func toggleProtection() {
        setProtection(enabled: !isProtected)
    }

    // MARK: - Kiểm tra trạng thái tự động

    public func verifyStatus() async {
        isChecking = true
        defer { isChecking = false }

        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            if manager.isEnabled {
                self.isProtected = true
                UserDefaults.standard.set(true, forKey: "aimhub_dns_anti_enabled")
                return
            }
        } catch {}

        // Fallback kiểm tra NextDNS info API
        guard let url = URL(string: "https://dns.nextdns.io/info") else { return }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.5
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                self.isProtected = true
                UserDefaults.standard.set(true, forKey: "aimhub_dns_anti_enabled")
                return
            }
        } catch {}

        // Nếu cả 2 đều không bật
        self.isProtected = false
        UserDefaults.standard.set(false, forKey: "aimhub_dns_anti_enabled")
    }

    public func startPolling() {
        stopPolling()
        Task { await verifyStatus() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        permissionPollTask?.cancel()
        permissionPollTask = nil
    }
}
