import Foundation
import NetworkExtension
import Combine
import UIKit

@MainActor
public final class DNSAntiManager: ObservableObject {
    public static let shared = DNSAntiManager()

    public let profileID = "2a91bf"
    public let serverURLString = "https://ios.dns.nextdns.io/2a91bf"
    public let profileDisplayName = "AimHub"

    @Published public var isProtected: Bool = false
    @Published public var isChecking: Bool = false
    @Published public var showInstallFallbackAlert: Bool = false

    private var permissionPollTask: Task<Void, Never>?

    private init() {
        self.isProtected = UserDefaults.standard.bool(forKey: "aimhub_dns_anti_enabled")
        setupNotificationObservers()
        Task {
            await verifyStatus()
        }
    }

    private func setupNotificationObservers() {
        // Chá»‰ kiá»ƒm tra khi cáº¥u hÃ¬nh DNS trong iOS thá»±c sá»± thay Ä‘á»•i
        NotificationCenter.default.addObserver(
            forName: .NEDNSSettingsConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }

        // Kiá»ƒm tra láº¡i khi ngÆ°á»i dÃ¹ng quay láº¡i app (tá»« mÃ n hÃ¬nh CÃ i Ä‘áº·t hoáº·c Ä‘a nhiá»‡m)
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

    // MARK: - YÃªu cáº§u cáº¥p quyá»n & Tá»± Ä‘á»™ng báº­t DNS AimHub

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
            for _ in 0..<10 { // Thá»­ tá»‘i Ä‘a 10 láº§n (5 giÃ¢y) Ä‘á»ƒ báº¯t popup Cho phÃ©p
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

    // MARK: - Báº­t DNS Anti (LÆ°u cáº¥u hÃ¬nh chuáº©n AimHub)

    public func startProtection() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()

            let dohSettings = NEDNSOverHTTPSSettings(servers: ["45.90.28.0", "45.90.30.0", "2a07:a8c0::", "2a07:a8c1::"])
            dohSettings.serverURL = URL(string: serverURLString)
            manager.dnsSettings = dohSettings
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            manager.localizedDescription = profileDisplayName // Hiá»ƒn thá»‹ Ä‘Ãºng chá»¯ "AimHub"

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

    // MARK: - Táº¯t DNS Anti

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

    // MARK: - Kiá»ƒm tra tráº¡ng thÃ¡i á»•n Ä‘á»‹nh (KHÃ”NG nháº£y tráº¡ng thÃ¡i gÃ¢y giáº­t lag)

    public func verifyStatus() async {
        isChecking = true
        defer { isChecking = false }

        // 1. Kiá»ƒm tra tráº¡ng thÃ¡i manager trong iOS
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            guard manager.isEnabled else {
                self.isProtected = false
                UserDefaults.standard.set(false, forKey: "aimhub_dns_anti_enabled")
                return
            }
        } catch {
            // Lá»—i Ä‘á»c preferences táº¡m thá»i -> giá»¯ nguyÃªn tráº¡ng thÃ¡i
            return
        }

        // 2. Kiá»ƒm tra trá»±c tiáº¿p gÃ³i tin tá»« NextDNS
        let active = await checkLiveNextDNSProfile()
        self.isProtected = active
        UserDefaults.standard.set(active, forKey: "aimhub_dns_anti_enabled")
    }

    private func checkLiveNextDNSProfile() async -> Bool {
        guard let url = URL(string: "https://test.nextdns.io") else { return self.isProtected }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 4.0
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return self.isProtected // Náº¿u server test báº­n, giá»¯ nguyÃªn tráº¡ng thÃ¡i cÅ©
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                if status == "ok" {
                    if let prof = json["profile"] as? String {
                        return prof == profileID
                    }
                    return true
                } else if status == "unconfigured" {
                    // NgÆ°á»i dÃ¹ng Ä‘Ã£ chá»§ Ä‘á»™ng táº¯t trong cÃ i Ä‘áº·t iOS
                    return false
                }
            }
            return self.isProtected
        } catch {
            // Máº¡ng yáº¿u, lag hoáº·c rá»›t gÃ³i tin -> khÃ´ng tá»± ngáº¯t tráº¡ng thÃ¡i báº£o vá»‡
            return self.isProtected
        }
    }

    public func startPolling() {
        // KhÃ´ng dÃ¹ng polling timer dÃ y Ä‘áº·c Ä‘á»ƒ trÃ¡nh lÃ m lag vÃ  ngáº¯t káº¿t ná»‘i DNS cá»§a iOS
    }

    public func stopPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = nil
    }
}