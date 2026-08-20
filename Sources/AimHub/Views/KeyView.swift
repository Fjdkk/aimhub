import SwiftUI

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

                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
                .scaleEffect(appear ? 1 : 0.6)
                .opacity(appear ? 1 : 0)
                .padding(.bottom, 22)

                // Tiêu đề
                Text("NHẬP KEY KÍCH HOẠT")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                Text("Nhập key được cấp để mở khóa AimHub trên thiết bị này.")
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

                    TextField("Nhập mã key...", text: $keyInput)
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
                                Text("ĐANG KÍCH HOẠT...")
                            }
                        } else {
                            Text("KÍCH HOẠT")
                        }
                    }
                }
                .primaryButton()
                .disabled(loading)
                .padding(.horizontal, 24)
                .scaleEffect(loading ? 0.97 : 1)
                .opacity(loading ? 0.85 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: loading)
                .padding(.bottom, 14)

                Button("ĐỔI KEY") {
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

                VStack(spacing: 6) {
                    Text("© 2026 AimHub — Dev Quốc Dũng")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                    Text("Phiên bản 1.0")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted.opacity(0.7))
                }
                .padding(.bottom, 20)
                .opacity(appear ? 1 : 0)
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
            showError("Vui lòng nhập key.")
            return
        }
        guard value.count >= 8 else {
            showError("Key không tồn tại.")
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
}