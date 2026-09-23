import Foundation
import NetworkExtension
import Combine
import UIKit

@MainActor
public final class DNSAntiManager: ObservableObject {
    public static let shared = DNSAntiManager()

    @Published public var isProtected: Bool = false
    @Published public var isChecking: Bool = false

    private let userDefaultsKey = "aimhub.dnsAnti.enabled"
    private var pollTimer: Timer?

    private init() {
        self.isProtected = UserDefaults.standard.bool(forKey: userDefaultsKey)
        startPolling()
    }

    public func toggle() {
        setProtection(enabled: !isProtected)
    }

    public func setProtection(enabled: Bool) {
        isProtected = enabled
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)

        Task {
            if enabled {
                await applyNativeDNS()
            } else {
                await removeNativeDNS()
            }
            await verifyStatus()
        }
    }

    public func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func applyNativeDNS() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()

            let dohSettings = NEDNSOverHTTPSSettings(servers: ["45.90.28.0", "45.90.30.0"])
            dohSettings.serverURL = URL(string: "https://dns.nextdns.io/1a48d7")
            manager.dnsSettings = dohSettings
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            manager.isEnabled = true

            try await manager.saveToPreferences()
        } catch {
            // Trường hợp không có quyền NetworkExtension, lưu state và kiểm tra profile ngoài
        }
    }

    private func removeNativeDNS() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            manager.isEnabled = false
            try await manager.saveToPreferences()
        } catch {
        }
    }

    public func verifyStatus() async {
        guard isProtected else { return }
        isChecking = true
        defer { isChecking = false }

        // Kiểm tra qua NEDNSSettingsManager nếu khả dụng
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            if manager.isEnabled {
                self.isProtected = true
                return
            }
        } catch {
        }

        // Hoặc kiểm tra qua test endpoint
        guard let url = URL(string: "https://test.nextdns.io") else { return }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 3.5
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "ok" {
                self.isProtected = true
            }
        } catch {
        }
    }
}
