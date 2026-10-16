import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var dnsManager = DNSAntiManager.shared
    @ObservedObject private var antiBanService = FFAntiBanService.shared
    @State private var showAbout = false
    @State private var showAntiBanLogs = false
    @State private var toastText: String?
    @State private var toastOK = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar

                statusCard

                SectionLabel(title: L10n.t("home.devices"))
                deviceCard

                patchNavigationCard
                    .padding(.top, 18)

                SectionLabel(title: L10n.t("home.notices"))
                if appState.notificationsEnabled {
                    noticeBanner
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.muted)
                            .frame(width: 8, height: 8)
                        Text(L10n.t("notices.off"))
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                        Spacer()
                        Image(systemName: "bell.slash")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.muted)
                    }
                    .card(padding: 14)
                }

                SectionLabel(title: L10n.t("home.stats"))
                statsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showAntiBanLogs) {
            AntiBanLogSheetView(antiBanService: antiBanService)
        }
        .alert(isPresented: $dnsManager.showInstallFallbackAlert) {
            Alert(
                title: Text("DNS Anti chưa kích hoạt"),
                message: Text("Hệ thống bảo vệ DNS Anti hiện đang TẮT.\n\nĐể kích hoạt bảo vệ, bạn vui lòng vào:\nCài đặt máy > Cài đặt chung > VPN & Quản lý thiết bị > DNS > Chọn AimHub."),
                primaryButton: .default(Text("Mở Cài Đặt")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text("Đã hiểu"))
            )
        }
        .overlay(alignment: .top) {
            if let toastText = toastText {
                toast(text: toastText, ok: toastOK)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text("AimHub")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            Spacer()
            Button {
                showAbout = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(.vertical, 10)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.isConnected ? Theme.green : Theme.red)
                    .frame(width: 9, height: 9)
                    .shadow(color: (appState.isConnected ? Theme.green : Theme.red).opacity(0.8), radius: 4)
                Text(appState.isConnected ? L10n.t("home.connected") : L10n.t("home.disconnected"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
            }
            if appState.isConnected {
                HStack(spacing: 10) {
                    Label("\(appState.pingMs ?? 0) ms", systemImage: "wifi")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                    Spacer()
                    Label("\(appState.appFPS)", systemImage: "speedometer")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }
                HStack(spacing: 10) {
                    Text("\(L10n.t("home.connectedSince")) \(connectedTimeText)")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                    Spacer()
                }
            }

            Rectangle()
                .fill(Theme.border.opacity(0.7))
                .frame(height: 1)
                .padding(.vertical, 2)

            Button {
                handleDNSTap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(dnsManager.isProtected ? Theme.green.opacity(0.15) : Theme.red.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(dnsManager.isProtected ? Theme.green.opacity(0.5) : Theme.red.opacity(0.5), lineWidth: 1)
                            )
                        Image(systemName: "shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(dnsManager.isProtected ? Theme.green : Theme.red)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("home.dnsAnti"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.text)
                        HStack(spacing: 6) {
                            Text(dnsManager.isProtected ? L10n.t("home.dnsProtected") : L10n.t("home.dnsOff"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(dnsManager.isProtected ? Theme.green : Theme.red)
                        }
                    }

                    Spacer()

                    if dnsManager.isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: dnsManager.isProtected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(dnsManager.isProtected ? Theme.green : Theme.red)
                    }
                }
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Theme.border.opacity(0.7))
                .frame(height: 1)
                .padding(.vertical, 2)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(antiBanService.isAntiBanActive ? Theme.green.opacity(0.15) : Theme.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(antiBanService.isAntiBanActive ? Theme.green.opacity(0.5) : Theme.accent.opacity(0.5), lineWidth: 1)
                        )
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(antiBanService.isAntiBanActive ? Theme.green : Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("AntiBan V2")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.text)

                        if !antiBanService.logs.isEmpty {
                            Button {
                                showAntiBanLogs = true
                            } label: {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.accent)
                                    .padding(3)
                                    .background(Theme.accent.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(antiBanService.isAntiBanActive ? "Đã dọn sạch & Khóa log (LIVE)" : (antiBanService.isActivating ? antiBanService.currentStepText : "Sẵn sàng dọn dẹp"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(antiBanService.isAntiBanActive ? Theme.green : Theme.muted)
                    }
                }

                Spacer()

                Button {
                    handleAntiBanClean()
                } label: {
                    HStack(spacing: 5) {
                        if antiBanService.isActivating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(antiBanService.isActivating ? "Đang dọn..." : "Dọn dẹp")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        antiBanService.isAntiBanActive ?
                            LinearGradient(colors: [Theme.green, Theme.green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                            Theme.gradient()
                    )
                    .clipShape(Capsule())
                    .shadow(color: (antiBanService.isAntiBanActive ? Theme.green : Theme.accent).opacity(0.3), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(antiBanService.isActivating)
            }
        }
        .card(padding: 14)
    }

    private var connectedTimeText: String {
        guard let since = appState.connectedSince else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: since)
    }

    private var deviceCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L10n.t("home.model")).foregroundColor(Theme.text)
                Spacer()
                Text(DeviceInfo.modelName).foregroundColor(Theme.muted)
            }
            HStack {
                Text(L10n.t("home.ios")).foregroundColor(Theme.text)
                Spacer()
                Text(DeviceInfo.osVersion).foregroundColor(Theme.muted)
            }
            HStack {
                Text(L10n.t("home.game")).foregroundColor(Theme.text)
                Spacer()
                if let game = appState.activeGame {
                    Text("\(game.name): \(L10n.t("home.gameSelected"))")
                        .foregroundColor(Theme.green)
                } else {
                    Text(L10n.t("home.noGame"))
                        .foregroundColor(Theme.orange)
                }
            }
        }
        .card()
    }

    private var patchNavigationCard: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appState.selectedTab = .patch
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.gradient())
                        .frame(width: 44, height: 44)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 2)

                    PatchTabIcon(isActive: true)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("home.goToPatch"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(L10n.t("home.goToPatchDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(8)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(14)
            .background(
                LinearGradient(colors: [Theme.accent.opacity(0.25), Theme.card], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.accent.opacity(0.45), lineWidth: 1.2)
            )
            .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 3)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }

    private var noticeBanner: some View {
        Button {
            appState.openNoticesRequest = true
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(appState.unreadAnnouncementCount > 0 ? Theme.accent : Theme.orange)
                    .frame(width: 9, height: 9)
                    .shadow(color: (appState.unreadAnnouncementCount > 0 ? Theme.accent : Theme.orange).opacity(0.8), radius: 4)
                if let ann = appState.announcements.first {
                    Text(ann.date ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.card2)
                        .cornerRadius(6)
                    Text(ann.title)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                } else {
                    Text(L10n.t("home.noNotice"))
                        .font(.system(size: 14))
                        .foregroundColor(Theme.text)
                }
                Spacer()
                if appState.unreadAnnouncementCount > 0 {
                    Text("\(appState.unreadAnnouncementCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.gradient())
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
            }
            .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("home.modsOn")).foregroundColor(Theme.text)
                Spacer()
                Text("\(appState.activeMods.count) / \(totalMods)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(appState.activeMods.isEmpty ? Theme.muted : Theme.accent)
            }

            if !appState.activeModNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(appState.activeModNames, id: \.self) { name in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Theme.green)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: Theme.green.opacity(0.8), radius: 3)
                                Text(name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.text)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.card2)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.muted.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(L10n.t("home.noModOn"))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .card(padding: 14)
    }

    private var totalMods: Int {
        guard let game = appState.activeGame else { return 0 }
        let rules = game.projects?.first?.rules?.count
        return rules ?? 0
    }

    private func handleAntiBanTap() {
        let bundleID = appState.activeGame?.bundleID ?? GameBundleID.freeFireMax
        if antiBanService.isAntiBanActive {
            showToast("🛡️ Delta Isolation đang bảo vệ LIVE (17 Telemetry + 11 Caches đã khóa)", ok: true)
        } else {
            showToast("⚡ Đang thanh tẩy Telemetry & Content Caches...", ok: true)
            let directContainer = try? ContainerAccess.shared.gameContainerPath(bundleID: bundleID)
            antiBanService.purgeTelemetryAndIntegrity(bundleID: bundleID, directContainer: directContainer)
            antiBanService.normalizeMetadata(bundleID: bundleID, directContainer: directContainer)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.showToast("🛡️ Đã cô lập Sandbox thành công! Sẵn sàng vào game.", ok: true)
            }
        }
    }

    private func handleDNSTap() {
        Task {
            await dnsManager.verifyStatus()
            if !dnsManager.isProtected {
                dnsManager.requestPermission()
                dnsManager.showInstallFallbackAlert = true
                showToast("⚠️ DNS Anti hiện chưa bật! Hãy vào Cài đặt để kích hoạt.", ok: false)
            } else {
                showToast("✅ DNS Anti đang kích hoạt và bảo vệ an toàn!", ok: true)
            }
        }
    }

    private func toast(text: String, ok: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark" : "exclamationmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ok ? Theme.green : Theme.red)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .stroke((ok ? Theme.green : Theme.red).opacity(0.6), lineWidth: 1.5)
                )
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.text)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ok ? Theme.green.opacity(0.45) : Theme.red.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
    }

    private func showToast(_ message: String, ok: Bool = true) {
        withAnimation { toastText = message; toastOK = ok }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { toastText = nil }
        }
    }
}

// MARK: - AntiBan V2 Terminal Log Sheet
struct AntiBanLogSheetView: View {
    @ObservedObject var antiBanService: FFAntiBanService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                if antiBanService.logs.isEmpty {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 8) {
                                            ProgressView()
                                                .scaleEffect(1.0)
                                                .tint(Theme.accent)
                                            Text("Đang khởi động tiến trình dọn dẹp...")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(Theme.muted)
                                        }
                                        .padding(.top, 40)
                                        Spacer()
                                    }
                                } else {
                                    ForEach(Array(antiBanService.logs.enumerated()), id: \.offset) { idx, log in
                                        Text(log)
                                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                                            .foregroundColor(colorForLog(log))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(idx)
                                    }
                                }
                            }
                            .padding(14)
                        }
                        .onChange(of: antiBanService.logs.count) { _ in
                            if let last = antiBanService.logs.indices.last {
                                withAnimation {
                                    proxy.scrollTo(last, anchor: .bottom)
                                }
                            }
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(antiBanService.isAntiBanActive ? Theme.green : (antiBanService.isActivating ? Theme.orange : Theme.muted))
                                .frame(width: 8, height: 8)
                            Text(antiBanService.isAntiBanActive ? "Delta Engine LIVE" : (antiBanService.isActivating ? "Đang xử lý..." : "Sẵn sàng"))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.white)
                        }

                        Spacer()

                        Button {
                            let bundleID = GameBundleID.freeFireMax
                            antiBanService.runAntiBanV2PreClean(bundleID: bundleID) { _ in }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Dọn lại")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.card2)
                            .cornerRadius(6)
                        }
                        .disabled(antiBanService.isActivating)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.card)
                }
            }
            .navigationTitle("Nhật ký AntiBan V2")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private func colorForLog(_ log: String) -> Color {
        if log.contains("===") || log.contains("HOAN TAT") {
            return Theme.green
        } else if log.contains("[1/3]") || log.contains("[2/3]") || log.contains("[3/3]") {
            return Theme.accent
        } else if log.contains("Da xoa") || log.contains("Xoa") || log.contains("Hoan tat") {
            return Theme.green.opacity(0.85)
        } else if log.contains("THAT BAI") || log.contains("Loi") {
            return Theme.red
        } else {
            return Theme.text.opacity(0.8)
        }
    }
}
