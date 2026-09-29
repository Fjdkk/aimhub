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

    private var permissionPollTask: Task<Void, Never>?

    private init() {
        self.isProtected = false
        setupNotificationObservers()
        Task {
            await verifyStatus()
        }
    }

    private func setupNotificationObservers() {
        // Chỉ kiểm tra khi cấu hình DNS trong iOS thực sự thay đổi
        NotificationCenter.default.addObserver(
            forName: .NEDNSSettingsConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }

        // Kiểm tra lại khi người dùng quay lại app (từ màn hình Cài đặt hoặc đa nhiệm)
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
            startPermissionCheckPolling()
        }
    }

    private func startPermissionCheckPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task {
            for _ in 0..<10 { // Thử tối đa 10 lần (5 giây) để bắt popup Cho phép
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

    // MARK: - Bật DNS Anti (Lưu cấu hình chuẩn AimHub)

    public func startProtection() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()

            let dohSettings = NEDNSOverHTTPSSettings(servers: ["45.90.28.0", "45.90.30.0", "2a07:a8c0::", "2a07:a8c1::"])
            dohSettings.serverURL = URL(string: serverURLString)
            manager.dnsSettings = dohSettings
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            manager.localizedDescription = profileDisplayName // Hiển thị đúng chữ "AimHub"

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()

            if manager.isEnabled {
                self.isProtected = true
                UserDefaults.standard.set(true, forKey: "aimhub_dns_anti_enabled")
            } else {
                self.isProtected = false
                UserDefaults.standard.set(false, forKey: "aimhub_dns_anti_enabled")
                self.showInstallFallbackAlert = true
            }
        } catch {
            print("[DNSAnti] DNS settings failed: \(error)")
            self.isProtected = false
            UserDefaults.standard.set(false, forKey: "aimhub_dns_anti_enabled")
            self.showInstallFallbackAlert = true
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

    // MARK: - Kiểm tra trạng thái ổn định (KHÔNG lưu đè để tránh ngắt DNS)

    public func verifyStatus() async {
        isChecking = true
        defer { isChecking = false }

        // 1. Kiểm tra trạng thái manager trong iOS
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            guard manager.isEnabled else {
                self.isProtected = false
                UserDefaults.standard.set(false, forKey: "aimhub_dns_anti_enabled")
                return
            }
        } catch {
            self.isProtected = false
            UserDefaults.standard.set(false, forKey: "aimhub_dns_anti_enabled")
            return
        }

        // 2. Kiểm tra trực tiếp gói tin từ NextDNS
        let active = await checkLiveNextDNSProfile()
        self.isProtected = active
        UserDefaults.standard.set(active, forKey: "aimhub_dns_anti_enabled")
    }

    private func checkLiveNextDNSProfile() async -> Bool {
        guard let url = URL(string: "https://test.nextdns.io") else { return false }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.0
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return false
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                if status == "ok" {
                    if let prof = json["profile"] as? String {
                        return prof == profileID
                    }
                    return true
                }
                return false
            }
            return false
        } catch {
            return false
        }
    }

    public func startPolling() {
        // Không dùng polling timer dày đặc để tránh làm lag và ngắt kết nối DNS của iOS
    }

    public func stopPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = nil
    }
}
