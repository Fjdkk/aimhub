import SwiftUI

struct UpdateBlockedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(Theme.gradient())
                .padding(.bottom, 18)

            Text("BẢN CẬP NHẬT MỚI ĐÃ CÓ")
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

            Text("Bản này đã bị khóa")
                .font(.system(size: 19, weight: .heavy))
                .foregroundColor(Theme.text)
                .padding(.bottom, 10)

            VStack(spacing: 4) {
                Text("Dev đã phát hành phiên bản mới của AimHub.")
                Text("Bản IPA bạn đang dùng không còn được hỗ trợ.")
                Text("")
                Text("Vui lòng xóa bản IPA này và liên hệ")
                Text("Admin để nhận bản cập nhật mới nhất.")
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .padding(.bottom, 22)

            if let url = URL(string: "https://zalo.me/0336898934") {
                Link(destination: url) {
                    Text("LIÊN HỆ ADMIN")
                }
                .primaryButton()
                .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 6) {
                Text("AimHub \(appState.versionInfo?.latestVersion ?? "1.0") · Bản mới nhất: \(appState.versionInfo?.latestVersion ?? "—")")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted.opacity(0.7))
            }
            .padding(.bottom, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}