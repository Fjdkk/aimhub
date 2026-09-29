import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var route: Route?
    @State private var showKeyDetail = false
    @State private var showNotices = false
    @State private var showHelp = false
    @State private var showLog = false
    @State private var showLang = false
    @State private var showAbout = false

    enum Route: String, Identifiable {
        case keyDetail, notices, help, log, lang, about
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.text)
                    Spacer()
                }
                .padding(.vertical, 10)

                SectionLabel(title: L10n.t("settings.section"))

                settingsRow("key", title: L10n.t("settings.myKey"), action: { route = .keyDetail })
                settingsRow("arrow.left.square", title: "Đổi Key / Nhập Key Khác", action: {
                    appState.clearKey()
                })

                Toggle(isOn: $appState.notificationsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.accent)
                            .frame(width: 26)
                        Text(L10n.t("settings.notifs"))
                            .font(.system(size: 15))
                            .foregroundColor(Theme.text)
                    }
                }
                .tint(Theme.accent)
                .padding(15)
                .background(Theme.card)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .padding(.bottom, 10)

                settingsRow("bell.badge",
                            title: L10n.t("settings.notifHistory"),
                            action: { route = .notices },
                            trailing: appState.unreadAnnouncementCount > 0 ? "\(appState.unreadAnnouncementCount)" : nil)
                settingsRow("wrench.and.screwdriver", title: L10n.t("settings.help"), action: { route = .help })
                settingsRow("list.bullet", title: L10n.t("settings.log"), action: { route = .log })
                settingsRow("globe", title: L10n.t("settings.language"), action: { route = .lang })
                settingsRow("info.circle", title: L10n.t("settings.about"), action: { route = .about })

                Button {
                    if let url = URL(string: "https://zalo.me/0336898934") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.accent)
                        Text(L10n.t("settings.contactAdmin"))
                            .font(.system(size: 15))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Text("Zalo")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.gradient())
                            .cornerRadius(18)
                            .shadow(color: Theme.accent.opacity(0.35), radius: 8)
                    }
                    .padding(15)
                    .background(
                        LinearGradient(colors: [Theme.accent.opacity(0.12), Theme.accent2.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $route) { r in
            switch r {
            case .keyDetail: KeyDetailView()
            case .notices: NoticesView()
            case .help: HelpView()
            case .log: LogView()
            case .lang: LanguageView()
            case .about: AboutView()
            }
        }
    }

    private func settingsRow(_ icon: String, title: String,
                            action: @escaping () -> Void,
                            trailing: String? = nil) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Theme.accent)
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                Spacer()
                if let trailing = trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Theme.accent)
                        .cornerRadius(10)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.muted)
            }
            .padding(15)
            .background(Theme.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .padding(.bottom, 10)
    }
}