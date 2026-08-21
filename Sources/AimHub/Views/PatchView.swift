import SwiftUI

struct PatchView: View {
    @EnvironmentObject var appState: AppState
    @State private var loading = true
    @State private var showMods = false

    private let fallbackGames = [
        Game(game: "Free Fire", bundleID: GameBundleID.freeFire, projects: nil),
        Game(game: "Free Fire Max", bundleID: GameBundleID.freeFireMax, projects: nil),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                Text(L10n.t("patch.online"))
                    .font(.system(size: 12, weight: .medium))
                    .kerning(0.5)
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 4)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                Text(L10n.t("patch.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 14)

                if loading && appState.games.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    let list = appState.games.isEmpty ? fallbackGames : appState.games
                    ForEach(list) { game in
                        gameRow(game)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .fullScreenCover(isPresented: $showMods) {
            if let selected = appState.activeGame {
                ModListView(game: selected)
            }
        }
        .task {
            guard appState.games.isEmpty else {
                loading = false
                return
            }
            loading = true
            await appState.loadGames()
            loading = false
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            PatchLogoView(size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("PATCH")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accent2],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                Text("AimHub Mod Library")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.muted)
            }

            Spacer()
        }
        .padding(.top, 10)
    }

    private func gameRow(_ game: Game) -> some View {
        Button {
            appState.selectGame(game)
            showMods = true
        } label: {
            HStack(spacing: 14) {
                Image(gameLogoName(game.bundleID))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(game.bundleID)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }
            .card(padding: 15)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .padding(.bottom, 10)
    }

    private func gameLogoName(_ bundleID: String) -> String {
        switch bundleID {
        case GameBundleID.freeFireMax: return "GameFFMax"
        case GameBundleID.freeFire: return "GameFF"
        default: return "Logo"
        }
    }
}

/// Patch Logo native: crosshair (tâm ngắm) kết hợp vi mạch/chip gaming,
/// viền glowing gradient cyan-purple trên nền dark glass. Vẽ bằng SwiftUI nên
/// nét luôn sắc ở mọi kích thước, không bị mờ như ảnh/SVG đơn sắc.
struct PatchLogoView: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            // Nền khối dập nổi
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(colors: [Theme.card2, Theme.card],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(
                    LinearGradient(colors: [Theme.accent.opacity(0.85), Theme.accent2.opacity(0.85)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.4
                )

            crosshair
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.30), radius: size * 0.25, y: size * 0.08)
    }

    private var crosshair: some View {
        ZStack {
            // Vòng ngoài
            Circle()
                .stroke(
                    LinearGradient(colors: [Theme.accent, Theme.accent2],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.8
                )
                .frame(width: size * 0.62, height: size * 0.62)

            // Vòng trong
            Circle()
                .stroke(Theme.text.opacity(0.55), lineWidth: 1)
                .frame(width: size * 0.30, height: size * 0.30)

            // Dấu chéo tâm ngắm
            Path { p in
                let m = size * 0.5
                let gap = size * 0.16
                let len = size * 0.30
                p.move(to: CGPoint(x: m, y: gap))
                p.addLine(to: CGPoint(x: m, y: len + gap))
                p.move(to: CGPoint(x: gap, y: m))
                p.addLine(to: CGPoint(x: len + gap, y: m))
            }
            .stroke(
                LinearGradient(colors: [Theme.accent, Theme.accent2],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )

            // Chấm tâm
            Circle()
                .fill(Theme.text)
                .frame(width: 3.4, height: 3.4)
                .shadow(color: Theme.accent, radius: 4)
        }
    }
}

/// Icon crosshair nhỏ gọn dùng cho thanh Tab (thay SF Symbol "scope" đơn sắc).
struct PatchTabIcon: View {
    var isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(colors: [Theme.accent, Theme.accent2],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 2
                )
                .frame(width: 20, height: 20)

            if isActive {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 5, height: 5)
                    .shadow(color: Theme.accent.opacity(0.8), radius: 3)
            } else {
                Circle()
                    .fill(Theme.muted)
                    .frame(width: 5, height: 5)
            }
        }
    }
}
