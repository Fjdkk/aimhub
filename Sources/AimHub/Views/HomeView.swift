import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAbout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar

                statusCard

                SectionLabel(title: "THIẾT BỊ")
                deviceCard

                openGameButton
                    .padding(.top, 18)

                SectionLabel(title: "THÔNG BÁO")
                if appState.notificationsEnabled {
                    noticeBanner
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.muted)
                            .frame(width: 9, height: 9)
                        Text("Đã tắt thông báo")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.muted)
                        Spacer()
                        Image(systemName: "bell.slash")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.muted)
                    }
                    .card(padding: 14)
                }

                SectionLabel(title: "THỐNG KÊ")
                statsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showAbout) {
            AboutView()
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
        HStack(spacing: 8) {
            Circle()
                .fill(appState.isConnected ? Theme.green : Theme.red)
                .frame(width: 9, height: 9)
                .shadow(color: (appState.isConnected ? Theme.green : Theme.red).opacity(0.8), radius: 4)
            Text(appState.isConnected ? "Đã kết nối server ✓" : "Mất kết nối server")
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
        }
        .card(padding: 14)
    }

    private var deviceCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Model").foregroundColor(Theme.text)
                Spacer()
                Text(DeviceInfo.modelName).foregroundColor(Theme.muted)
            }
            HStack {
                Text("iOS").foregroundColor(Theme.text)
                Spacer()
                Text(DeviceInfo.osVersion).foregroundColor(Theme.muted)
            }
            HStack {
                Text("Game").foregroundColor(Theme.text)
                Spacer()
                if let game = appState.activeGame {
                    Text("\(game.name): Đã chọn ✓")
                        .foregroundColor(Theme.green)
                } else {
                    Text("Chưa chọn")
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
                    Text(appState.activeGame?.name ?? "Chưa chọn game")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(appState.activeGame == nil ? "Vào tab PATCH để chọn game" : "Bấm để mở game đã chọn")
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
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.orange)
                .frame(width: 9, height: 9)
                .shadow(color: Theme.orange.opacity(0.8), radius: 4)
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
                Text("Chưa có thông báo")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text)
            }
            Spacer()
        }
        .card(padding: 14)
    }

    private var statsCard: some View {
        HStack {
            Text("Mod đang bật").foregroundColor(Theme.text)
            Spacer()
            Text("\(appState.activeModID != nil ? 1 : 0) / \(totalMods)")
                .foregroundColor(Theme.muted)
        }
        .card(padding: 14)
    }

    private var totalMods: Int {
        guard let game = appState.activeGame else { return 0 }
        let rules = game.projects?.first?.rules?.count
        return rules ?? 0
    }
}