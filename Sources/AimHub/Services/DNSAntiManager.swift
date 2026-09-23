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
    @Published public var isVPNActive: Bool = false

    private var pollTimer: Timer?

    private init() {
        self.isProtected = UserDefaults.standard.bool(forKey: "aimhub_dns_anti_enabled")
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.verifyStatus()
            }
        }

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

    public func openSettingsPage() {
        Task { @MainActor in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    public func openProfileInstallPage() {
        openSettingsPage()
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

    private func startProtection() async {
        // 1. Thử khởi chạy VPN Packet Tunnel trước (NextDNSProxy.appex)
        let vpnStarted = await startVPNTunnel()
        if vpnStarted {
            await MainActor.run {
                self.isProtected = true
                self.isVPNActive = true
            }
            return
        }

        // 2. Nếu VPN Tunnel không khả dụng, nạp Native DoH
        await applyNativeDNS()
    }

    private func startVPNTunnel() async -> Bool {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            let manager = managers.first ?? NETunnelProviderManager()

            let proto = NETunnelProviderProtocol()
            let hostBundleID = Bundle.main.bundleIdentifier ?? "com.apple.mobile.MobileHouseArrest"
            proto.providerBundleIdentifier = "\(hostBundleID).NextDNSProxy"
            proto.serverAddress = "NextDNS"
            proto.providerConfiguration = [
                "configurationId": profileID
            ]

            manager.protocolConfiguration = proto
            manager.localizedDescription = "AimHub Anti-Cheat (NextDNS)"
            manager.isEnabled = true

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()

            if let session = manager.connection as? NETunnelProviderSession {
                try session.startVPNTunnel(options: nil)
                return true
            }
        } catch {
            print("[DNSAnti] VPN tunnel failed, falling back to Native DNS: \(error)")
        }
        return false
    }

    private func applyNativeDNS() async {
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
                await MainActor.run {
                    self.isProtected = true
                }
            } else {
                await MainActor.run {
                    self.isProtected = false
                    self.showInstallFallbackAlert = true
                }
            }
        } catch {
            print("[DNSAnti] Native DNS failed: \(error)")
            await MainActor.run {
                self.isProtected = false
                self.showInstallFallbackAlert = true
            }
        }
    }

    private func stopProtection() async {
        // Tắt VPN Tunnel
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            for m in managers {
                m.isEnabled = false
                try? await m.saveToPreferences()
                if let session = m.connection as? NETunnelProviderSession {
                    session.stopVPNTunnel()
                }
            }
        } catch {}

        // Tắt Native DNS
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            try await manager.removeFromPreferences()
        } catch {}
    }

    public func verifyStatus() async {
        guard isProtected else {
            self.isVPNActive = false
            return
        }
        isChecking = true
        defer { isChecking = false }

        // 1. Kiểm tra trạng thái VPN Tunnel
        if let managers = try? await NETunnelProviderManager.loadAllFromPreferences(),
           let manager = managers.first {
            if manager.connection.status == .connected || manager.connection.status == .connecting {
                self.isVPNActive = true
                self.isProtected = true
                return
            }
        }

        // 2. Kiểm tra trạng thái NEDNSSettingsManager
        do {
            let manager = NEDNSSettingsManager.shared()
            try await manager.loadFromPreferences()
            if manager.isEnabled {
                self.isProtected = true
                return
            }
        } catch {}

        // 3. Fallback kiểm tra NextDNS info API
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
