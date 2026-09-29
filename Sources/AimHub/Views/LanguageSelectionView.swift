import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedLanguage: Language = .vietnamese
    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Cyber Neon Background Glows
            LinearGradient(
                colors: [Theme.accent.opacity(0.16), .clear, Theme.accent2.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo with Sweep Effect
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Theme.accent.opacity(0.4), radius: 14, y: 4)
                    .lightSweep(duration: 3.5, pause: 2.0, intensity: 0.4)
                    .scaleEffect(appear ? 1 : 0.8)
                    .opacity(appear ? 1 : 0)
                    .padding(.bottom, 20)

                // App Title
                Text("AIMHUB")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: Theme.accent.opacity(0.5), radius: 10)
                    .opacity(appear ? 1 : 0)

                // Subtitle
                VStack(spacing: 4) {
                    Text(L10n.t("lang.chooseTitle", selectedLanguage))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text(L10n.t("lang.chooseSub", selectedLanguage))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
                .opacity(appear ? 1 : 0)

                // Language Option Cards
                VStack(spacing: 12) {
                    languageOptionCard(
                        lang: .vietnamese,
                        title: "Tiếng Việt",
                        subtitle: "Giao diện tiếng Việt (Khuyên dùng)",
                        flag: "🇻🇳"
                    )

                    languageOptionCard(
                        lang: .english,
                        title: "English",
                        subtitle: "English language interface",
                        flag: "🇬🇧"
                    )
                }
                .padding(.horizontal, 22)
                .opacity(appear ? 1 : 0)

                Spacer()

                // Continue Button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        appState.setInitialLanguage(selectedLanguage)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(L10n.t("lang.continue", selectedLanguage))
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .primaryButton()
                .buttonStyle(PressableButtonStyle(scale: 0.96))
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            selectedLanguage = appState.language
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }

    private func languageOptionCard(lang: Language, title: String, subtitle: String, flag: String) -> some View {
        let isSelected = selectedLanguage == lang

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedLanguage = lang
            }
        } label: {
            HStack(spacing: 14) {
                Text(flag)
                    .font(.system(size: 32))
                    .padding(4)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isSelected ? .white : Theme.text)

                        if lang == .vietnamese {
                            Text("MẶC ĐỊNH")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(Theme.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.green.opacity(0.18))
                                .cornerRadius(5)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : Theme.muted)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 12, height: 12)
                            .shadow(color: Theme.accent.opacity(0.8), radius: 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected
                ? AnyShapeStyle(LinearGradient(colors: [Theme.accent.opacity(0.24), Theme.card], startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(Theme.card)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.accent.opacity(0.7) : Theme.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Theme.accent.opacity(0.2) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
