import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var dnsManager = DNSAntiManager.shared
    @State private var showAbout = false
    @State private var toastText: String?
    @State private var toastOK = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar

                statusCard

                SectionLabel(title: L10n.t("home.devices"))
                deviceCard

                openGameButton
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
        .alert(isPresented: $dnsManager.showInstallFallbackAlert) {
            Alert(
                title: Text("Cần cấp quyền AimHub"),
                message: Text("Bạn cần vào Cài đặt máy > Cài đặt chung > VPN & Quản lý thiết bị > DNS và chọn tích vào AimHub để kích hoạt bảo vệ."),
                dismissButton: .default(Text("Đã hiểu"))
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

    private var openGameButton: some View {
        Button {
            appState.openGame()
        } label: {
            HStack(spacing: 12) {
                Image(gameIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.activeGame?.name ?? L10n.t("home.noGameTitle"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(appState.activeGame == nil ? L10n.t("home.pickInPatch") : L10n.t("home.openGame"))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(15)
            .background(Theme.gradient())
            .cornerRadius(16)
            .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 4)
        }
    }

    private var gameIconName: String {
        switch appState.activeGame?.bundleID {
        case GameBundleID.freeFireMax: return "GameFFMax"
        case GameBundleID.freeFire: return "GameFF"
        default: return "Logo"
        }
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

    private func handleDNSTap() {
        if !dnsManager.isProtected {
            dnsManager.requestPermission()
            showToast("Đang kích hoạt AimHub...", ok: true)
        } else {
            showToast("AimHub đang bảo vệ an toàn ✓", ok: true)
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