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
                SheetNavBar(title: L10n.t("sub.myKey"))
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 6) {
                            Text("KEY")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted)
                            Text(appState.activeKey?.key ?? "—")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(Theme.text)
                            Text(L10n.t("sub.loggedIn"))
                                .font(.system(size: 13))
                                .foregroundColor(Theme.green)
                        }
                        .frame(maxWidth: .infinity)
                        .card(padding: 18)

                        SectionLabel(title: L10n.t("sub.keyInfo"))
                        VStack(spacing: 0) {
                            kvRow("Key", appState.activeKey?.key ?? "—")
                            kvRow(L10n.t("sub.device"), DeviceInfo.modelName)
                            kvRow(L10n.t("sub.timeLeft"), expiresText)
                        }
                        .card(padding: 12)

                        Button {
                            appState.clearKey()
                            dismiss()
                        } label: {
                            Text(L10n.t("key.change"))
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
        return L10n.t("sub.forever")
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
                SheetNavBar(title: L10n.t("sub.notices"))
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(appState.announcements.enumerated()), id: \.element.id) { index, ann in
                            noticeRow(ann)
                                .overlay(alignment: .bottom) {
                                    if index < appState.announcements.count - 1 {
                                        Rectangle()
                                            .fill(Theme.border)
                                            .frame(height: 0.5)
                                    }
                                }
                        }
                        if appState.announcements.isEmpty {
                            Text(L10n.t("sub.noNotices"))
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
        .onAppear {
            // Mở màn hình là đánh dấu toàn bộ đã đọc
            appState.markAllAnnouncementsRead()
        }
    }

    private func noticeRow(_ ann: Announcement) -> some View {
        let isUnread = !NotificationManager.shared.readAnnouncementIds.contains(ann.id)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                // Chấm xanh báo chưa đọc
                Circle()
                    .fill(isUnread ? Theme.accent : Color.clear)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ann.title)
                        .font(.system(size: 14, weight: isUnread ? .bold : .semibold))
                        .foregroundColor(Theme.text)

                    if let content = ann.content, !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if let date = ann.date {
                    Text(date)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.card2)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

struct HelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SheetNavBar(title: L10n.t("sub.helpContact"))
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(title: L10n.t("sub.howto"))
                        VStack(spacing: 14) {
                            step(1, L10n.t("sub.step1"))
                            step(2, L10n.t("sub.step2"))
                            step(3, L10n.t("sub.step3"))
                        }
                        .card(padding: 14)

                        Button {
                            if let url = URL(string: "https://zalo.me/0336898934") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(L10n.t("sub.report"))
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

                        SectionLabel(title: L10n.t("sub.contact"))
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
                    Text(L10n.t("sub.log"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Button(L10n.t("sub.clear")) {
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
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted)
                                    .monospacedDigit()

                                Image(systemName: iconName(entry.level))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(color(entry.level))
                                    .frame(width: 16)

                                Text(entry.message)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.text)
                                    .fixedSize(horizontal: false, vertical: true)

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
                            Text(L10n.t("sub.noLog"))
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

    private func color(_ level: LogLevel) -> Color {
        switch level {
        case .info: return Theme.accent
        case .success: return Theme.green
        case .warning: return Theme.orange
        case .error: return Theme.red
        }
    }

    private func iconName(_ level: LogLevel) -> String {
        switch level {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct LanguageView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SheetNavBar(title: L10n.t("sub.language"))
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
                SheetNavBar(title: L10n.t("sub.about"))
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
                            Text("\(L10n.t("sub.currentVersion")) \(versionString)")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                        SectionLabel(title: L10n.t("sub.version"))
                        VStack(spacing: 0) {
                            kv(L10n.t("sub.currentVersion"), versionString)
                            kv(L10n.t("sub.verify"), L10n.t("sub.latest"), color: Theme.green)
                            kv(L10n.t("sub.iosSupport"), iosSupportStatus.text, color: iosSupportStatus.color)
                            HStack {
                                Text(L10n.t("sub.verifiedRange")).foregroundColor(Theme.muted)
                                Spacer()
                                Text(iosRange.isEmpty ? L10n.t("sub.supported") : iosRange)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 10)
                        }
                        .card(padding: 12)

                        SectionLabel(title: L10n.t("sub.deviceSect"))
                        VStack(spacing: 0) {
                            kv(L10n.t("home.model"), DeviceInfo.modelName)
                            kv(L10n.t("home.ios"), DeviceInfo.osVersion)
                            kv(L10n.t("sub.deviceID"), DeviceInfo.identifier)
                            kv(L10n.t("sub.status"),
                               appState.isConnected ? L10n.t("sub.connected") : L10n.t("sub.disconnected"),
                               color: appState.isConnected ? Theme.green : Theme.red)
                        }
                        .card(padding: 12)

                        SectionLabel(title: L10n.t("sub.credits"))
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

    private var iosSupportStatus: (text: String, color: Color) {
        // 1. Kiểm tra nạp thư viện Sandbox Container hệ thống
        guard ContainerAccess.shared.isAvailable else {
            return (L10n.t("sub.sandboxRestricted"), Theme.red)
        }

        // 2. Kiểm tra dải phiên bản iOS từ Server (nếu có cấu hình trên Admin)
        let list = appState.versionInfo?.iosSupported ?? []
        if list.isEmpty {
            return (L10n.t("sub.supported"), Theme.green)
        }

        let currentVer = DeviceInfo.osVersion
        let matches = list.contains { rangeStr in
            checkVersionMatch(current: currentVer, range: rangeStr)
        }

        if matches {
            return (L10n.t("sub.supported"), Theme.green)
        } else {
            return (L10n.t("sub.unverified"), Theme.orange)
        }
    }

    private func checkVersionMatch(current: String, range: String) -> Bool {
        let clean = range.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return false }
        if clean.contains("-") {
            let parts = clean.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let minVer = parts[0]
                let maxVer = parts[1]
                return current.compare(minVer, options: .numeric) != .orderedAscending &&
                       current.compare(maxVer, options: .numeric) != .orderedDescending
            }
        }
        return current.hasPrefix(clean)
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