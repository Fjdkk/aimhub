import Foundation
import UIKit
import UserNotifications

/// Quản lý thông báo cho AimHub:
/// 1. Thông báo từ Web Admin (server announcements) — fetch định kỳ, khi có bài mới
///    từ Admin sẽ hiện push banner + âm thanh + badge ngay lập tức.
/// 2. Thông báo nhắc nhở định kỳ (local reminder) — giữ nguyên tính năng cũ.
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    private let enabledKey = "aimhub.notificationsEnabled"
    private let intervalKey = "aimhub.notifications.intervalMinutes"
    private let pendingID = "aimhub.reminder"

    // Trạng thái đọc/chưa đọc của thông báo server
    private let readIdsKey = "aimhub.readAnnouncementIds"

    /// Dùng cho thông báo server: prefix id để phân biệt với reminder
    private let announcementPrefix = "aimhub.ann."

    public var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if newValue {
                requestAuthorizationAndSchedule()
            } else {
                cancel()
            }
        }
    }

    /// Chu kỳ thông báo nhắc nhở (phút). Mặc định 180 phút = 3 giờ.
    public var intervalMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: intervalKey)
            return v > 0 ? v : 180
        }
        set {
            UserDefaults.standard.set(newValue, forKey: intervalKey)
            if isEnabled {
                reschedule()
            }
        }
    }

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    public func configure() {
        // Bật sẵn cho người dùng mới lần đầu mở app
        if !UserDefaults.standard.contains(key: enabledKey) {
            isEnabled = true
        } else if isEnabled {
            requestAuthorizationAndSchedule()
        }
    }

    public func requestAuthorizationAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                self.schedule()
            }
        }
    }

    /// Lên lịch thông báo nhắc nhở lặp lại, mỗi lần cách nhau intervalMinutes phút.
    private func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [pendingID])

        let content = UNMutableNotificationContent()
        content.title = "AimHub"
        content.body = Self.nextMessage()
        content.sound = .default

        let interval = Double(max(intervalMinutes, 1) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)

        let request = UNNotificationRequest(identifier: pendingID, content: content, trigger: trigger)
        center.add(request)
    }

    public func reschedule() {
        schedule()
    }

    public func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pendingID])
    }

    // MARK: - Thông báo từ Web Admin (server announcements)

    /// Danh sách id thông báo đã đọc (lưu persistent).
    public var readAnnouncementIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: readIdsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: readIdsKey)
        }
    }

    public func markAnnouncementsRead(_ ids: [String]) {
        var current = readAnnouncementIds
        current.formUnion(ids)
        readAnnouncementIds = current
        updateBadgeCount(0)
    }

    /// Hiện push banner ngay lập tức khi Admin đăng thông báo mới.
    public func showNewAnnouncement(id: String, title: String, content: String?) {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard granted, let self = self else { return }
            let notifContent = UNMutableNotificationContent()
            notifContent.title = title
            notifContent.body = content?.isEmpty == false ? content! : title
            notifContent.sound = .default
            notifContent.userInfo = ["announcementID": id]

            // Không dùng trigger -> thông báo được phát ngay lập tức
            let request = UNNotificationRequest(
                identifier: self.announcementPrefix + id,
                content: notifContent,
                trigger: nil
            )
            center.add(request)
        }
    }

    /// Cập nhật số badge trên icon app (số thông báo chưa đọc).
    public func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }

    /// Nội dung quay vòng cho thông báo nhắc nhở.
    private static func nextMessage() -> String {
        let messages = [
            "Mod mới đã có! Vào bật mod săn top ngay 🔥",
            "Key của bạn vẫn đang hoạt động. Đừng quên bật mod trước khi vào trận!",
            "Nhiều người đang dùng AimHub lắm đấy, vào thử mod hot nhất ngay!",
            "Đổi game ngay hôm nay — FF lẫn FF Max đều hỗ trợ, kích hoạt chỉ 1 chạm!",
            "Sắp có mod mới cực ngầu! Mở AimHub để không bỏ lỡ nhé ⚡",
            "Bạn vẫn ổn chứ? Ghé AimHub nhận ưu đãi & mod miễn phí nào!",
            "Mẹo hay: vào game qua AimHub để file mod tự động kích hoạt chuẩn nhất!",
            "Giữ nguyên key để không bị gián đoạn. Kiểm tra tình trạng trong AimHub!",
            "Game thủ đang săn điểm với mod mới nhất — bạn còn chần chừ gì nữa?",
            "Nhắc nhẹ: tắt mod trong lúc không chơi để an toàn & kéo dài thời gian dùng nhé!"
        ]
        let idx = Int(Date().timeIntervalSince1970 / 10800) % messages.count
        return messages[idx]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // App đang mở: vẫn hiện banner + âm thanh (native iOS behavior)
        completionHandler([.banner, .sound, .badge])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // User bấm vào thông báo từ Admin -> mở màn hình Lịch sử thông báo
        if response.notification.request.identifier.hasPrefix(announcementPrefix) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .aimhubOpenNotices, object: nil)
            }
        }
        completionHandler()
    }
}

extension Notification.Name {
    /// Post khi user bấm vào push notification của thông báo Admin.
    public static let aimhubOpenNotices = Notification.Name("aimhub.openNotices")
}

private extension UserDefaults {
    func contains(key: String) -> Bool {
        object(forKey: key) != nil
    }
}
