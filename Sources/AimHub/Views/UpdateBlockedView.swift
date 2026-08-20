import SwiftUI

struct UpdateBlockedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.bottom, 18)

            Text(L10n.t("update.badge"))
                .font(.system(size: 11, weight: .bold))
                .kerning(1)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(colors: [Theme.red, Color(red: 1.0, green: 0.176, blue: 0.333)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color(red: 1.0, green: 0.176, blue: 0.333).opacity(0.4), radius: 12)
                )
                .padding(.bottom, 10)

            Text(L10n.t("update.blocked"))
                .font(.system(size: 19, weight: .heavy))
                .foregroundColor(Theme.text)
                .padding(.bottom, 10)

            VStack(spacing: 4) {
                Text(L10n.t("update.newVersion"))
                Text(L10n.t("update.notSupported"))
                Text("")
                Text(L10n.t("update.removeIpa"))
                Text(L10n.t("update.contact"))
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .padding(.bottom, 22)

            if let url = URL(string: "https://zalo.me/0336898934") {
                Link(destination: url) {
                    Text(L10n.t("key.contactTitle"))
                }
                .primaryButton()
                .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 6) {
                Text("AimHub \(appState.versionInfo?.latestVersion ?? "1.0") · \(L10n.t("update.latestIs")): \(appState.versionInfo?.latestVersion ?? "—")")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted.opacity(0.7))
            }
            .padding(.bottom, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}