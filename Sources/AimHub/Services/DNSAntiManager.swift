import Foundation
import NetworkExtension
import Combine
import UIKit

@MainActor
public final class DNSAntiManager: ObservableObject {
    public static let shared = DNSAntiManager()

    public let profileID = "62aaee"
    public let serverURLString = "https://62aaee.dns.nextdns.io"

    @Published public var isProtected: Bool = false
    @Published public var isChecking: Bool = false
    @Published public var showInstallFallbackAlert: Bool = false

    private var pollTimer: Timer?

    private init() {
        self.isProtected = UserDefaults.standard.bool(forKey: "aimhub_dns_anti_enabled")
    }

    public func setProtection(enabled: Bool) {
        isProtected = enabled
        UserDefaults.standard.set(enabled, forKey: "aimhub_dns_anti_enabled")

        Task {
            if enabled {
                await applyNativeDNS()
            } else {
                await removeNativeDNS()
            }
            await verifyStatus()
        }
    }

    public func toggleProtection() {
        setProtection(enabled: !isProtected)
    }

    public func openProfileInstallPage() {
        if let url = URL(string: "https://apple.nextdns.io/\(profileID)") {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }

    public func startPolling() {
        stopPolling()
        Task { await verifyStatus() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
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
            dohSettings.serverURL = URL(string: serverURLString)
            manager.dnsSettings = dohSettings
            manager.onDemandRules = [NEOnDemandRuleConnect()]

            try await manager.saveToPreferences()
        } catch {
            await MainActor.run {
                self.showInstallFallbackAlert = true
            }
        }
    }

    private func removeNativeDNS() async {
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            try await manager.removeFromPreferences()
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
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = json["status"] as? String
                let profile = json["profile"] as? String
                if status == "ok" && (profile == nil || profile == profileID) {
                    self.isProtected = true
                }
            }
        } catch {
        }
    }
}
