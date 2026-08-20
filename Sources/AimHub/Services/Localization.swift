import Foundation

/// Hệ thống ngôn ngữ tập trung: `L10n.t("key")` tự đọc ngôn ngữ hiện tại.
/// AppState gán `L10n.current = language` khi user đổi ngôn ngữ.
public enum L10n {
    public static var current: Language = .vietnamese

    public static func t(_ key: String) -> String {
        dict[key]?[current] ?? dict[key]?[.vietnamese] ?? key
    }

    public static func t(_ key: String, _ lang: Language) -> String {
        dict[key]?[lang] ?? dict[key]?[.vietnamese] ?? key
    }

    private static let dict: [String: [Language: String]] = [
        // ===== Tab =====
        "tab.home": [.vietnamese: "HOME", .english: "HOME"],
        "tab.patch": [.vietnamese: "PATCH", .english: "PATCH"],
        "tab.settings": [.vietnamese: "SETTINGS", .english: "SETTINGS"],

        // ===== KeyView (login) =====
        "key.title": [.vietnamese: "NHẬP KEY KÍCH HOẠT", .english: "ENTER ACTIVATION KEY"],
        "key.subtitle": [.vietnamese: "Nhập key được cấp để mở khóa AimHub trên thiết bị này.", .english: "Enter the key you were given to unlock AimHub on this device."],
        "key.placeholder": [.vietnamese: "Nhập mã key...", .english: "Enter key..."],
        "key.activating": [.vietnamese: "ĐANG KÍCH HOẠT...", .english: "ACTIVATING..."],
        "key.activate": [.vietnamese: "KÍCH HOẠT", .english: "ACTIVATE"],
        "key.change": [.vietnamese: "ĐỔI KEY", .english: "CHANGE KEY"],
        "key.empty": [.vietnamese: "Vui lòng nhập key.", .english: "Please enter a key."],
        "key.invalid": [.vietnamese: "Key không tồn tại.", .english: "Key does not exist."],
        "key.contactTitle": [.vietnamese: "LIÊN HỆ ADMIN", .english: "CONTACT ADMIN"],
        "key.contactSub": [.vietnamese: "Cần key hoặc cần hỗ trợ?", .english: "Need a key or support?"],
        "key.copyright": [.vietnamese: "© 2026 AimHub — Dev Quốc Dũng", .english: "© 2026 AimHub — Dev Quốc Dũng"],

        // ===== Home =====
        "home.devices": [.vietnamese: "THIẾT BỊ", .english: "DEVICE"],
        "home.notices": [.vietnamese: "THÔNG BÁO", .english: "NOTICES"],
        "home.stats": [.vietnamese: "THỐNG KÊ", .english: "STATS"],
        "home.connected": [.vietnamese: "Đã kết nối server ✓", .english: "Connected to server ✓"],
        "home.disconnected": [.vietnamese: "Mất kết nối server", .english: "Disconnected from server"],
        "home.notifsOff": [.vietnamese: "Đã tắt thông báo", .english: "Notifications off"],
        "home.model": [.vietnamese: "Model", .english: "Model"],
        "home.ios": [.vietnamese: "iOS", .english: "iOS"],
        "home.game": [.vietnamese: "Game", .english: "Game"],
        "home.gameSelected": [.vietnamese: "Đã chọn ✓", .english: "Selected ✓"],
        "home.noGame": [.vietnamese: "Chưa chọn", .english: "Not selected"],
        "home.noGameTitle": [.vietnamese: "Chưa chọn game", .english: "No game selected"],
        "home.pickInPatch": [.vietnamese: "Vào tab PATCH để chọn game", .english: "Go to PATCH tab to pick a game"],
        "home.openGame": [.vietnamese: "Bấm để mở game đã chọn", .english: "Tap to open the selected game"],
        "home.noNotice": [.vietnamese: "Chưa có thông báo", .english: "No notices yet"],
        "home.modsOn": [.vietnamese: "Mod đang bật", .english: "Mods enabled"],
        "home.ping": [.vietnamese: "Ping", .english: "Ping"],
        "home.fps": [.vietnamese: "FPS", .english: "FPS"],
        "home.connectedSince": [.vietnamese: "Kết nối lúc", .english: "Connected at"],
        "home.latency": [.vietnamese: "Độ trễ", .english: "Latency"],

        // ===== Patch =====
        "patch.online": [.vietnamese: "THƯ VIỆN ONLINE", .english: "ONLINE LIBRARY"],
        "patch.subtitle": [.vietnamese: "Chọn bản game bạn đang chơi để xem các mod có sẵn.", .english: "Pick the game you're playing to see available mods."],
        "patch.loading": [.vietnamese: "Đang tải...", .english: "Loading..."],

        // ===== Mod list =====
        "mod.oneAtATime": [.vietnamese: "Chỉ được bật 1 mod. Bật mod khác thì mod cũ tự tắt.", .english: "Only 1 mod at a time. Enabling another turns off the previous one."],
        "mod.none": [.vietnamese: "Chưa có mod nào cho game này.", .english: "No mods for this game yet."],
        "mod.reset": [.vietnamese: "RESET MẶC ĐỊNH", .english: "RESET TO DEFAULT"],
        "mod.resetHint": [.vietnamese: "Khi bật mod, file gốc của game được tự sao lưu trước khi ghi. Bấm RESET để khôi phục file gốc và tắt hết mod.", .english: "When you enable a mod, the game's original files are backed up before writing. Tap RESET to restore originals and turn off all mods."],
        "mod.on": [.vietnamese: "Đã bật %@ ✓", .english: "%@ enabled ✓"],
        "mod.off": [.vietnamese: "Đã tắt %@ và khôi phục file gốc", .english: "%@ off and originals restored"],
        "mod.allRestored": [.vietnamese: "Đã khôi phục toàn bộ file gốc", .english: "All original files restored"],

        // ===== Settings =====
        "settings.section": [.vietnamese: "CÀI ĐẶT", .english: "SETTINGS"],
        "settings.myKey": [.vietnamese: "Key của tôi", .english: "My Key"],
        "settings.notifs": [.vietnamese: "Thông báo", .english: "Notifications"],
        "settings.notifHistory": [.vietnamese: "Lịch sử thông báo", .english: "Notification history"],
        "settings.help": [.vietnamese: "Trợ giúp / Liên hệ", .english: "Help / Contact"],
        "settings.log": [.vietnamese: "Nhật ký phiên", .english: "Session log"],
        "settings.language": [.vietnamese: "Ngôn ngữ", .english: "Language"],
        "settings.about": [.vietnamese: "Thông tin ứng dụng", .english: "About"],
        "settings.diag": [.vietnamese: "Chẩn đoán container game", .english: "Game container diagnosis"],
        "settings.contactAdmin": [.vietnamese: "Liên hệ Admin", .english: "Contact Admin"],

        // ===== SubViews =====
        "sub.myKey": [.vietnamese: "Key của tôi", .english: "My Key"],
        "sub.keyInfo": [.vietnamese: "THÔNG TIN KEY", .english: "KEY INFO"],
        "sub.loggedIn": [.vietnamese: "Đăng nhập thành công ✓", .english: "Logged in successfully ✓"],
        "sub.device": [.vietnamese: "Thiết bị", .english: "Device"],
        "sub.timeLeft": [.vietnamese: "Thời gian còn lại", .english: "Time remaining"],
        "sub.forever": [.vietnamese: "Vĩnh viễn", .english: "Forever"],
        "sub.notices": [.vietnamese: "Thông báo", .english: "Notices"],
        "sub.noNotices": [.vietnamese: "Chưa có thông báo.", .english: "No notices yet."],
        "sub.helpContact": [.vietnamese: "Trợ giúp / Liên hệ", .english: "Help / Contact"],
        "sub.howto": [.vietnamese: "HƯỚNG DẪN SỬ DỤNG", .english: "HOW TO USE"],
        "sub.step1": [.vietnamese: "Chọn game (Free Fire / FF Max)", .english: "Pick a game (Free Fire / FF Max)"],
        "sub.step2": [.vietnamese: "Bật mod mong muốn", .english: "Enable the mod you want"],
        "sub.step3": [.vietnamese: "Mở game chơi", .english: "Open the game and play"],
        "sub.report": [.vietnamese: "BÁO LỖI", .english: "REPORT BUG"],
        "sub.contact": [.vietnamese: "LIÊN HỆ", .english: "CONTACT"],
        "sub.log": [.vietnamese: "Nhật ký phiên", .english: "Session log"],
        "sub.clear": [.vietnamese: "XÓA", .english: "CLEAR"],
        "sub.noLog": [.vietnamese: "Chưa có nhật ký.", .english: "No log entries yet."],
        "sub.language": [.vietnamese: "Ngôn ngữ", .english: "Language"],
        "sub.about": [.vietnamese: "Thông tin ứng dụng", .english: "About"],
        "sub.version": [.vietnamese: "PHIÊN BẢN", .english: "VERSION"],
        "sub.currentVersion": [.vietnamese: "Phiên bản hiện tại", .english: "Current version"],
        "sub.verify": [.vietnamese: "Xác minh", .english: "Verification"],
        "sub.latest": [.vietnamese: "Bản mới nhất ✓", .english: "Latest ✓"],
        "sub.iosSupport": [.vietnamese: "Hỗ trợ iOS", .english: "iOS support"],
        "sub.supported": [.vietnamese: "Được hỗ trợ ✓", .english: "Supported ✓"],
        "sub.verifiedRange": [.vietnamese: "Phạm vi đã xác minh", .english: "Verified range"],
        "sub.deviceSect": [.vietnamese: "THIẾT BỊ", .english: "DEVICE"],
        "sub.deviceID": [.vietnamese: "Mã thiết bị", .english: "Device ID"],
        "sub.status": [.vietnamese: "Trạng thái", .english: "Status"],
        "sub.connected": [.vietnamese: "Đã kết nối server ✓", .english: "Connected to server ✓"],
        "sub.disconnected": [.vietnamese: "Mất kết nối", .english: "Disconnected"],
        "sub.credits": [.vietnamese: "GHI CÔNG", .english: "CREDITS"],

        "update.blocked": [.vietnamese: "Bản này đã bị khóa", .english: "This build is blocked"],
        "update.badge": [.vietnamese: "BẢN CẬP NHẬT MỚI ĐÃ CÓ", .english: "A NEW UPDATE IS AVAILABLE"],
        "update.newVersion": [.vietnamese: "Dev đã phát hành phiên bản mới của AimHub.", .english: "The dev has released a new AimHub version."],
        "update.notSupported": [.vietnamese: "Bản IPA bạn đang dùng không còn được hỗ trợ.", .english: "The IPA you're using is no longer supported."],
        "update.removeIpa": [.vietnamese: "Vui lòng xóa bản IPA này và liên hệ", .english: "Please delete this IPA and contact"],
        "update.contact": [.vietnamese: "Admin để nhận bản cập nhật mới nhất.", .english: "Admin for the latest update."],
        "update.latestIs": [.vietnamese: "Bản mới nhất", .english: "Latest is"],

        // ===== Update blocked =====
        "update.tag": [.vietnamese: "BẢN CẬP NHẬT MỚI ĐÃ CÓ", .english: "NEW UPDATE AVAILABLE"],
        "update.title": [.vietnamese: "Bản này đã bị khóa", .english: "This version is blocked"],
        "update.desc1": [.vietnamese: "Dev đã phát hành phiên bản mới của AimHub.", .english: "A new version of AimHub has been released."],
        "update.desc2": [.vietnamese: "Bản IPA bạn đang dùng không còn được hỗ trợ.", .english: "The IPA you're using is no longer supported."],
        "update.desc3": [.vietnamese: "Vui lòng xóa bản IPA này và liên hệ", .english: "Please delete this IPA and contact"],
        "update.desc4": [.vietnamese: "Admin để nhận bản cập nhật mới nhất.", .english: "the admin to get the latest update."],
        "update.contact": [.vietnamese: "LIÊN HỆ ADMIN", .english: "CONTACT ADMIN"],

        // ===== Server errors =====
        "err.invalidURL": [.vietnamese: "URL không hợp lệ", .english: "Invalid URL"],
        "err.http": [.vietnamese: "Lỗi server (%d)", .english: "Server error (%d)"],
        "err.decoding": [.vietnamese: "Lỗi dữ liệu: %@", .english: "Data error: %@"],
        "err.keyNotFound": [.vietnamese: "Key không tồn tại", .english: "Key does not exist"],
        "err.keyExpired": [.vietnamese: "Key đã hết hạn", .english: "Key has expired"],
        "err.deviceMismatch": [.vietnamese: "Key đã được kích hoạt trên thiết bị khác", .english: "Key already activated on another device"],
    ]
}