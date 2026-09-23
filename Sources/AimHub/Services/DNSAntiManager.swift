import Foundation
import NetworkExtension
import Combine
import UIKit

@MainActor
public final class DNSAntiManager: ObservableObject {
    public static let shared = DNSAntiManager()

    public let profileID = "62aaee"
    public let serverURLString = "https://ios.dns.nextdns.io/62aaee"

    @Published public var isProtected: Bool = false
    @Published public var isChecking: Bool = false
    @Published public var showInstallFallbackAlert: Bool = false

    private var pollTimer: Timer?

    private init() {
        self.isProtected = UserDefaults.standard.bool(forKey: "aimhub_dns_anti_enabled")
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .NEDNSSettingsConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }
    }

    public func setProtection(enabled: Bool) {
        isProtected = enabled
        UserDefaults.standard.set(enabled, forKey: "aimhub_dns_anti_enabled")

        Task {
            if enabled {
                await startProtection()
            } else {
                await stopProtection()
            }
            await verifyStatus()
        }
    }

    public func toggleProtection() {
        setProtection(enabled: !isProtected)
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
    }

    // MARK: - Bật DNS Anti (chuẩn NextDNS: NEDNSSettingsManager + NEOnDemandRuleConnect)

    private func startProtection() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()

            let dohSettings = NEDNSOverHTTPSSettings(servers: ["45.90.28.0", "45.90.30.0", "2a07:a8c0::", "2a07:a8c1::"])
            dohSettings.serverURL = URL(string: serverURLString)
            manager.dnsSettings = dohSettings
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            manager.localizedDescription = "AimHub Anti-Cheat (NextDNS)"

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()

            if manager.isEnabled {
                self.isProtected = true
            } else {
                self.isProtected = false
                self.showInstallFallbackAlert = true
            }
        } catch {
            print("[DNSAnti] DNS settings failed: \(error)")
            self.isProtected = false
            self.showInstallFallbackAlert = true
        }
    }

    // MARK: - Tắt DNS Anti (chuẩn NextDNS: NEOnDemandRuleDisconnect)

    private func stopProtection() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()

            manager.onDemandRules = [NEOnDemandRuleDisconnect()]
            try await manager.saveToPreferences()
        } catch {
            print("[DNSAnti] Failed to disconnect DNS: \(error)")
        }
    }

    // MARK: - Kiểm tra trạng thái

    public func verifyStatus() async {
        guard isProtected else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            if manager.isEnabled {
                self.isProtected = true
                return
            }
        } catch {}

        // Fallback kiểm tra NextDNS info API
        guard let url = URL(string: "https://dns.nextdns.io/info") else { return }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 3.0
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                self.isProtected = true
            }
        } catch {}
    }
}
