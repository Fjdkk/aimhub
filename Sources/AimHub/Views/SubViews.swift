import SwiftUI
import UIKit

struct SheetNavBar: View {
    let title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Theme.muted)
            }
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct KeyDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SheetNavBar(title: "Key của tôi")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 6) {
                            Text("KEY")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted)
                            Text(appState.activeKey?.key ?? "—")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(Theme.text)
                            Text("Đăng nhập thành công ✓")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.green)
                        }
                        .frame(maxWidth: .infinity)
                        .card(padding: 18)

                        SectionLabel(title: "THÔNG TIN KEY")
                        VStack(spacing: 0) {
                            kvRow("Key", appState.activeKey?.key ?? "—")
                            kvRow("Thiết bị", DeviceInfo.modelName)
                            kvRow("Thời gian còn lại", expiresText)
                        }
                        .card(padding: 12)

                        Button {
                            appState.clearKey()
                            dismiss()
                        } label: {
                            Text("ĐỔI KEY")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(Theme.text)
                                .background(Theme.card)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                        }
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var expiresText: String {
        if let raw = appState.activeKey?.expires,
           let date = ISO8601DateFormatter().date(from: raw) {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            formatter.locale = Locale(identifier: "vi_VN")
            return formatter.string(from: date)
        }
        return "Vĩnh viễn"
    }

    private func kvRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundColor(Theme.muted)
            Spacer()
            Text(value).foregroundColor(Theme.text)
        }
        .font(.system(size: 14))
        .padding(.vertical, 10)
    }
}

struct NoticesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SheetNavBar(title: "Thông báo")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(appState.announcements.enumerated()), id: \.element.id) { index, ann in
                            HStack(alignment: .top, spacing: 10) {
                                if let date = ann.date {
                                    Text(date)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.muted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.card2)
                                        .cornerRadius(6)
                                        .padding(.top, 1)
                                }
                                Text(ann.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                if index < appState.announcements.count - 1 {
                                    Rectangle()
                                        .fill(Theme.border)
                                        .frame(height: 0.5)
                                }
                            }
                        }
                        if appState.announcements.isEmpty {
                            Text("Chưa có thông báo.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 20)
                        }
                    }
                    .card(padding: 12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SheetNavBar(title: "Trợ giúp / Liên hệ")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(title: "HƯỚNG DẪN SỬ DỤNG")
                        VStack(spacing: 14) {
                            step(1, "Chọn game (Free Fire / FF Max)")
                            step(2, "Bật mod mong muốn")
                            step(3, "Mở game chơi")
                        }
                        .card(padding: 14)

                        Button {
                            if let url = URL(string: "https://zalo.me/0336898934") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("BÁO LỖI")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(Theme.text)
                                .background(Theme.card)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                        }
                        .padding(.top, 14)

                        SectionLabel(title: "LIÊN HỆ")
                        Button {
                            if let url = URL(string: "https://zalo.me/0336898934") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("Zalo").foregroundColor(Theme.muted)
                                Spacer()
                                Text("zalo.me/0336898934").foregroundColor(Theme.accent)
                            }
                            .font(.system(size: 14))
                            .card(padding: 14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func step(_ num: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(num)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 26, height: 26)
                .background(Theme.card2)
                .cornerRadius(13)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
            Spacer()
        }
    }
}

struct LogView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Theme.muted)
                    }
                    Text("Nhật ký phiên")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Button("XÓA") {
                        appState.clearLog()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(appState.sessionLog) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(timeString(entry.time))
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.muted)
                                    .monospacedDigit()
                                Text(entry.message)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.text)
                                Spacer()
                            }
                            .padding(.vertical, 9)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(height: 0.5)
                            }
                        }
                        if appState.sessionLog.isEmpty {
                            Text("Chưa có nhật ký.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 20)
                        }
                    }
                    .card(padding: 12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct LanguageView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SheetNavBar(title: "Ngôn ngữ")
                VStack(spacing: 0) {
                    langRow("Tiếng Việt", .vietnamese)
                    langRow("English", .english)
                }
                .card(padding: 12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
    }

    private func langRow(_ name: String, _ lang: Language) -> some View {
        Button {
            appState.language = lang
            dismiss()
        } label: {
            HStack {
                Text(name).font(.system(size: 15)).foregroundColor(Theme.text)
                Spacer()
                Circle()
                    .stroke(appState.language == lang ? Theme.accent : Theme.muted, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 10, height: 10)
                            .opacity(appState.language == lang ? 1 : 0)
                    }
            }
            .padding(.vertical, 12)
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SheetNavBar(title: "Thông tin ứng dụng")
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.bottom, 8)
                            Text("AimHub")
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundColor(Theme.text)
                            Text("Phiên bản 1.0")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                        SectionLabel(title: "PHIÊN BẢN")
                        VStack(spacing: 0) {
                            kv("Phiên bản hiện tại", versionString)
                            kv("Xác minh", "Bản mới nhất ✓", color: Theme.green)
                            kv("Hỗ trợ iOS", "Được hỗ trợ ✓", color: Theme.green)
                            HStack {
                                Text("Phạm vi đã xác minh").foregroundColor(Theme.muted)
                                Spacer()
                                Text(iosRange)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 10)
                        }
                        .card(padding: 12)

                        SectionLabel(title: "THIẾT BỊ")
                        VStack(spacing: 0) {
                            kv("Model", DeviceInfo.modelName)
                            kv("iOS", DeviceInfo.osVersion)
                            kv("Mã thiết bị", DeviceInfo.identifier)
                            kv("Trạng thái",
                               appState.isConnected ? "Đã kết nối server ✓" : "Mất kết nối",
                               color: appState.isConnected ? Theme.green : Theme.red)
                        }
                        .card(padding: 12)

                        SectionLabel(title: "GHI CÔNG")
                        VStack(spacing: 0) {
                            kv("AimHub", "Dev Quốc Dũng", color: Theme.accent)
                            kv("FilzaSlop", "file browser & sandbox escape")
                            kv("bad_query", "quyền ghi file game")
                            kv("Nugget / Pocket Poster", "kỹ thuật tham khảo")
                        }
                        .card(padding: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var iosRange: String {
        let list = appState.versionInfo?.iosSupported ?? []
        return list.joined(separator: "\n")
    }

    private func kv(_ key: String, _ value: String, color: Color = Theme.text) -> some View {
        HStack {
            Text(key).foregroundColor(Theme.muted)
            Spacer()
            Text(value).foregroundColor(color)
        }
        .font(.system(size: 14))
        .padding(.vertical, 10)
    }
}