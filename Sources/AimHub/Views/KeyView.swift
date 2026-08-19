import SwiftUI

struct KeyView: View {
    @EnvironmentObject var appState: AppState
    @State private var keyInput = ""
    @State private var errorText: String?
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(Theme.gradient())
                .padding(.bottom, 20)

            Text("NHẬP KEY KÍCH HOẠT")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.text)

            Text("Nhập key được cấp để mở khóa AimHub trên thiết bị này.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 6)
                .padding(.bottom, 28)

            TextField("Nhập mã key...", text: $keyInput)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .background(Theme.card)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(loading ? Theme.accent : Theme.border, lineWidth: 1)
                )
                .padding(.horizontal, 24)

            Text(errorText ?? " ")
                .font(.system(size: 12))
                .foregroundColor(Theme.red)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            Button {
                activate()
            } label: {
                Group {
                    if loading {
                        ProgressView().tint(.white)
                    } else {
                        Text("KÍCH HOẠT")
                    }
                }
            }
            .primaryButton()
            .disabled(loading)
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            Button("ĐỔI KEY") {
                keyInput = ""
                errorText = nil
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.accent)

            Spacer()

            VStack(spacing: 6) {
                Text("© 2026 AimHub — Dev Quốc Dũng")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                Text("Phiên bản 1.0")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted.opacity(0.7))
            }
            .padding(.bottom, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func activate() {
        let value = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            errorText = "Vui lòng nhập key."
            return
        }
        guard value.count >= 8 else {
            errorText = "Key không tồn tại."
            return
        }
        errorText = nil
        loading = true
        Task {
            do {
                try await appState.activateKey(value)
                loading = false
                await appState.loadGames()
            } catch {
                loading = false
                errorText = error.localizedDescription
            }
        }
    }
}