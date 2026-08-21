import SwiftUI
import UIKit

struct KeyView: View {
    @EnvironmentObject var appState: AppState
    @State private var keyInput = ""
    @State private var errorText: String?
    @State private var loading = false
    @State private var appear = false
    @State private var shake = false
    @State private var focused = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Nền glow mềm
            LinearGradient(
                colors: [Theme.accent.opacity(0.12), .clear, Theme.accent2.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + hiệu ứng ánh sáng kính lướt ngang theo chu kỳ
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
                    .lightSweep(duration: 3.8, pause: 2.2, intensity: 0.38)
                .scaleEffect(appear ? 1 : 0.6)
                .opacity(appear ? 1 : 0)
                .padding(.bottom, 22)

                // Tiêu đề
                Text(L10n.t("key.title"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                Text(L10n.t("key.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 6)
                    .padding(.bottom, 26)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                // Ô nhập key
                HStack(spacing: 10) {
                    Image(systemName: "key.horizontal")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.muted)

                    TextField(L10n.t("key.placeholder"), text: $keyInput)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Theme.text)
                        .font(.system(size: 16, weight: .medium))
                        .keyboardType(.asciiCapable)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Theme.card)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            loading ? Theme.accent : (focused ? Theme.accent.opacity(0.7) : Theme.border),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: focused ? Theme.accent.opacity(0.15) : .clear, radius: 10, y: 0)
                .padding(.horizontal, 24)
                .offset(x: shake ? -8 : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.25), value: shake)
                .onTapGesture { focused = true }

                // Thông báo lỗi (slide + fade)
                Group {
                    if let error = errorText, !error.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(3)
                        }
                        .foregroundColor(Theme.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.red.opacity(0.10))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    } else {
                        Text(" ")
                            .font(.system(size: 12))
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 16)

                // Nút kích hoạt
                Button {
                    activate()
                } label: {
                    Group {
                        if loading {
                            HStack(spacing: 10) {
                                ProgressView().tint(.white)
                                Text(L10n.t("key.activating"))
                            }
                        } else {
                            Text(L10n.t("key.activate"))
                        }
                    }
                }
                .primaryButton()
                .buttonStyle(PressableButtonStyle(scale: 0.96))
                .disabled(loading)
                .padding(.horizontal, 24)
                .scaleEffect(loading ? 0.97 : 1)
                .opacity(loading ? 0.85 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: loading)
                .padding(.bottom, 14)

                Button(L10n.t("key.change")) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        keyInput = ""
                        errorText = nil
                        focused = false
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(Theme.accent)
                .opacity(appear ? 1 : 0)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        if let url = URL(string: "https://zalo.me/0336898934") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 13))
                            Text(L10n.t("key.contactTitle"))
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Theme.accent.opacity(0.12))
                        .cornerRadius(20)
                        .overlay(
                            Capsule()
                                .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
                        )
                    }
                    Text(L10n.t("key.copyright"))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                    Text("\(L10n.t("sub.currentVersion")) \(versionString)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted.opacity(0.7))
                }
                .opacity(appear ? 1 : 0)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05)) {
                appear = true
            }
        }
    }

    private func activate() {
        let value = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            showError(L10n.t("key.empty"))
            return
        }
        guard value.count >= 8 else {
            showError(L10n.t("key.invalid"))
            return
        }
        errorText = nil
        loading = true
        focused = false
        Task {
            do {
                try await appState.activateKey(value)
                loading = false
                await appState.loadGames()
            } catch {
                loading = false
                showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            errorText = message
        }
        // Hiệu ứng lắc nhẹ
        Task { @MainActor in
            shake = true
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                shake = false
            }
        }
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}