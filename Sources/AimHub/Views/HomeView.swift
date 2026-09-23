import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var dnsManager = DNSAntiManager.shared
    @State private var showAbout = false

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
                title: Text("Bảo Vệ DNS Anti"),
                message: Text("Để kích hoạt bảo vệ DNS 62aaee trên thiết bị, bạn hãy tải và cài đặt hồ sơ cấu hình qua Safari."),
                primaryButton: .default(Text("Cài đặt ngay"), action: {
                    DNSAntiManager.shared.openProfileInstallPage()
                }),
                secondaryButton: .cancel(Text("Đóng"))
            )
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

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(appState.isDNSProtected ? Theme.accent.opacity(0.18) : Theme.card2)
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(appState.isDNSProtected ? Theme.accent.opacity(0.4) : Theme.border, lineWidth: 1)
                        )
                    Image(systemName: "shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(appState.isDNSProtected ? Theme.accent : Theme.muted)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("home.dnsAnti"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.text)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isDNSProtected ? Theme.green : Theme.muted.opacity(0.6))
                            .frame(width: 7, height: 7)
                            .shadow(color: (appState.isDNSProtected ? Theme.green : Color.clear).opacity(0.8), radius: 3)
                        Text(appState.isDNSProtected ? L10n.t("home.dnsProtected") : L10n.t("home.dnsOff"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(appState.isDNSProtected ? Theme.green : Theme.muted)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        DNSAntiManager.shared.openProfileInstallPage()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 19))
                            .foregroundColor(Theme.muted)
                    }

                    Toggle("", isOn: $appState.isDNSProtected)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
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
}