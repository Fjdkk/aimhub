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
                HStack {
                    Text("PATCH")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.text)
                    Spacer()
                }
                .padding(.vertical, 10)

                SectionLabel(title: "THƯ VIỆN ONLINE")
                Text("Chọn bản game bạn đang chơi để xem các mod có sẵn.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)

                if loading && appState.games.isEmpty {
                    VStack {
                        ProgressView()
                        Text("Đang tải...")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                            .padding(.top, 8)
                    }
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

    private func gameRow(_ game: Game) -> some View {
        Button {
            appState.selectGame(game)
            showMods = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: game.bundleID == GameBundleID.freeFireMax ? "flame.fill" : "flame")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.gradient())
                Text(game.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.muted)
            }
            .card(padding: 16)
        }
        .padding(.bottom, 10)
    }
}