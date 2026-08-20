import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .home

    enum Tab: Int {
        case home, patch, settings
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if appState.forceUpdate {
                UpdateBlockedView()
                    .transition(.opacity)
            } else if appState.activeKey == nil {
                KeyView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    ))
            } else {
                mainContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.activeKey)
        .onAppear {
            appState.start()
            Task {
                await appState.loadGames()
                await appState.loadAnnouncements()
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home: HomeView()
                case .patch: PatchView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
    }

    private var tabBar: some View {
        HStack {
            tabButton(.home, icon: "house.fill", label: L10n.t("tab.home"))
            tabButton(.patch, icon: "scope", label: L10n.t("tab.patch"))
            tabButton(.settings, icon: "gearshape.fill", label: L10n.t("tab.settings"))
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border.opacity(0.4)).frame(height: 0.5)
        }
    }

    private func tabButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                Rectangle()
                    .fill(Theme.gradient())
                    .frame(width: 18, height: 3)
                    .cornerRadius(2)
                    .opacity(selectedTab == tab ? 1 : 0)
            }
            .foregroundColor(selectedTab == tab ? Theme.accent : Theme.muted)
            .frame(maxWidth: .infinity)
        }
    }
}