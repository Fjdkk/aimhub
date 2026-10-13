import Foundation
import SwiftUI
import UIKit

public struct ActiveModItem: Codable, Equatable, Hashable {
    public let ruleID: String
    public let name: String
    public let destination: String
    public let conflictGroup: String?
    public let slot: String?

    public init(ruleID: String, name: String, destination: String, conflictGroup: String? = nil, slot: String? = nil) {
        self.ruleID = ruleID
        self.name = name
        self.destination = destination
        self.conflictGroup = conflictGroup
        self.slot = slot
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var activeKey: KeyInfo?
    @Published var activeGame: Game?
    @Published var activeMods: [String: ActiveModItem] = [:] // key: ruleID

    var activeModID: String? {
        activeMods.keys.first
    }

    var activeModNames: [String] {
        activeMods.values.map { $0.name }
    }

    func isModActive(ruleID: String) -> Bool {
        activeMods[ruleID] != nil
    }

    func activeMod(forDestination destination: String) -> ActiveModItem? {
        activeMods.values.first(where: { $0.destination == destination })
    }

    public enum AppTab: Int {
        case home, patch, settings
    }
    @Published var selectedTab: AppTab = .home

    @Published var forceUpdate: Bool = false
    @Published var isConnected = false
    @Published var announcements: [Announcement] = []
    @Published var unreadAnnouncementCount = 0
    /// Binding với sheet Lịch sử thông báo: true khi user bấm push notification.
    @Published var openNoticesRequest = false
    @Published var versionInfo: VersionInfo?
    @Published var sessionLog: [LogEntry] = []
    @Published var language: Language {
        didSet {
            L10n.current = language
            UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        }
    }
    @Published var hasSelectedLanguage: Bool {
        didSet {
            UserDefaults.standard.set(hasSelectedLanguage, forKey: hasSelectedLanguageKey)
        }
    }
    @Published var games: [Game] = []
    @Published var pingMs: Int?
    @Published var appFPS: Int = 0
    @Published var connectedSince: Date?
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: notificationsKey)
            NotificationManager.shared.isEnabled = notificationsEnabled
        }
    }
    @Published var isDNSProtected: Bool = false {
        didSet {
            if isDNSProtected != DNSAntiManager.shared.isProtected {
                DNSAntiManager.shared.setProtection(enabled: isDNSProtected)
            }
        }
    }

    private let server = ServerClient.shared
    private var started = false
    private let lastActiveKey = "aimhub.session.lastActiveAt"
    private let sessionStartKey = "aimhub.session.startedAt"
    private let notificationsKey = "aimhub.notificationsEnabled"
    private let languageKey = "aimhub.language"
    private let hasSelectedLanguageKey = "aimhub.hasSelectedLanguage"
    private var heartbeatTask: Task<Void, Never>?
    private var announcementPollTask: Task<Void, Never>?
    private var displayLink: CADisplayLink?
    /// Lưu id thông báo đã xử lý push trong phiên này để không push lại.
    private var pushedAnnouncementIds: Set<String> = []
    private var notificationTapToken: NSObjectProtocol?

    init() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: notificationsKey)
        hasSelectedLanguage = UserDefaults.standard.bool(forKey: hasSelectedLanguageKey)
        if let raw = UserDefaults.standard.string(forKey: languageKey),
           let lang = Language(rawValue: raw) {
            language = lang
        } else {
            language = .vietnamese
        }
        L10n.current = language
        if let saved = UserDefaults.standard.string(forKey: "activeBundleID") {
            loadActiveMods(for: saved)
        }
    }

    func setInitialLanguage(_ lang: Language) {
        language = lang
        hasSelectedLanguage = true
        // Xoá key cũ để user chắc chắn vào màn hình nhập key
        clearKey()
    }

    // MARK: - FPS monitor (CADisplayLink, ~1 lần/giây)

    private func startFPSMonitor() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: FPSTarget { [weak self] fps in
            Task { @MainActor in
                self?.appFPS = fps
            }
        }, selector: #selector(FPSTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func start() {
        guard !started else { return }
        started = true
        ContainerAccess.onDiagnostic = { [weak self] message in
            Task { @MainActor in
                self?.log(message)
            }
        }
        isDNSProtected = DNSAntiManager.shared.isProtected
        startFPSMonitor()
        activeKey = KeyStorage.load()
        NotificationManager.shared.configure()
        checkVersion()
        if activeKey != nil {
            if UserDefaults.standard.double(forKey: sessionStartKey) == 0 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: sessionStartKey)
            }
            checkBackgroundGap()
            startHeartbeat()
        }
        // Tự động kiểm tra và phục hồi giao dịch dở dang do văng app hoặc tắt nguồn
        PatchTransactionManager.shared.recoverPendingTransactionsIfNeeded()
        PatchTransactionManager.shared.cleanStagingAndTempFiles()

        Task { await loadAnnouncements() }
        startAnnouncementPolling()
    }

    func activateKey(_ key: String) async throws {
        let deviceID = DeviceInfo.identifier
        let info = try await server.activateKey(key: key, deviceID: deviceID)
        activeKey = info
        KeyStorage.save(info)
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: sessionStartKey)
        UserDefaults.standard.set(now, forKey: lastActiveKey)
        log("Kích hoạt key thành công", level: .success)
        startHeartbeat()
    }

    func clearKey() {
        activeKey = nil
        KeyStorage.clear()
        UserDefaults.standard.removeObject(forKey: lastActiveKey)
        UserDefaults.standard.removeObject(forKey: sessionStartKey)
        stopHeartbeat()
        stopPingLoop()
    }

    func checkVersion() {
        Task {
            do {
                versionInfo = try await server.fetchVersion()
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                if let minV = versionInfo?.minVersion,
                   compareVersions(current, minV) < 0 {
                    forceUpdate = true
                }
                if activeKey != nil {
                    checkBackgroundGap()
                }
            } catch {
                log("Kiểm tra phiên bản thất bại", level: .warning)
            }
        }
    }

    private var pingTask: Task<Void, Never>?

    func loadGames() async {
        do {
            games = try await server.fetchGames()
            isConnected = true
            if connectedSince == nil { connectedSince = Date() }
            log("Kết nối máy chủ thành công", level: .success)
            if let saved = UserDefaults.standard.string(forKey: "activeBundleID") {
                activeGame = games.first(where: { $0.bundleID == saved })
                loadActiveMods(for: saved)
            }
            startPingLoop()
        } catch {
            isConnected = false
            stopPingLoop()
            log("Lỗi kết nối máy chủ", level: .error)
        }
    }

    /// Đo ping mỗi 5 giây trong background khi đang kết nối.
    private func startPingLoop() {
        guard pingTask == nil else { return }
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isConnected else { break }
                let ms = await self.server.ping()
                if !Task.isCancelled {
                    self.pingMs = ms
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            self?.pingTask = nil
        }
    }

    private func stopPingLoop() {
        pingTask?.cancel()
        pingTask = nil
    }

    func selectGame(_ game: Game?) {
        if game?.bundleID != activeGame?.bundleID, !activeMods.isEmpty {
            try? ModManager.shared.restoreAll(bundleID: activeGame?.bundleID ?? "")
            saveActiveMods([:], for: activeGame?.bundleID ?? "")
            log("Đã khôi phục file gốc khi đổi game")
        }
        activeGame = game
        if let g = game {
            UserDefaults.standard.set(g.bundleID, forKey: "activeBundleID")
            loadActiveMods(for: g.bundleID)
        } else {
            activeMods = [:]
            UserDefaults.standard.removeObject(forKey: "activeBundleID")
        }
    }

    func installMod(_ mod: ModEntry, rule: RuleDetail) async throws {
        guard let game = activeGame else { throw ModManagerError.containerUnavailable }
        let dest = rule.destination ?? mod.files.first?.relativePath ?? "Documents/\(rule.ruleID).bin"
        let mode = rule.mode ?? "replace"
        
        var current = activeMods

        // 1. Nếu mode là replace (thay thế file game gốc), chỉ cho phép 1 mod trên cùng destination (ngoại trừ file patch AIO Assembly-CSharp-patch.bytes)
        if mode == "replace" && !dest.contains("Assembly-CSharp-patch.bytes") {
            let conflicting = current.values.filter { $0.destination == dest && $0.ruleID != rule.ruleID }
            for old in conflicting {
                try? ModManager.shared.restoreFile(relativePath: dest, bundleID: game.bundleID, mode: mode)
                current.removeValue(forKey: old.ruleID)
                log("Tự động tắt \(old.name) do cùng can thiệp file")
            }
        }

        // 2. Xử lý nhóm độc quyền (Aim Legit vs Aim Lock hoặc cùng conflictGroup)
        let isAimExclusive = (rule.slot == "aim_legit" || rule.slot == "aim_lock")
        for old in current.values {
            if old.ruleID == rule.ruleID { continue }
            let sameGroup = (rule.conflictGroup != nil && rule.conflictGroup == old.conflictGroup)
            let isOldAim = (old.slot == "aim_legit" || old.slot == "aim_lock")
            if sameGroup || (isAimExclusive && isOldAim) {
                current.removeValue(forKey: old.ruleID)
                log("Tự động chuyển đổi: tắt \(old.name) để bật \(rule.name)")
            }
        }

        try ModManager.shared.installMod(mod, bundleID: game.bundleID, mode: mode)
        current[rule.ruleID] = ActiveModItem(ruleID: rule.ruleID, name: rule.name, destination: dest, conflictGroup: rule.conflictGroup, slot: rule.slot)
        saveActiveMods(current, for: game.bundleID)
        log("Đã bật \(rule.name)")
    }

    func turnOffMod(_ rule: RuleDetail) async throws {
        guard let game = activeGame else { throw ModManagerError.containerUnavailable }
        let dest = rule.destination ?? "Documents/\(rule.ruleID).bin"
        let mode = rule.mode ?? "replace"
        
        var current = activeMods
        current.removeValue(forKey: rule.ruleID)
        saveActiveMods(current, for: game.bundleID)

        // Chỉ khôi phục/xóa file nếu không còn mod nào khác dùng chung destination
        let otherUsingSameDest = current.values.contains { $0.destination == dest }
        if !otherUsingSameDest {
            try ModManager.shared.restoreFile(relativePath: dest, bundleID: game.bundleID, mode: mode)
            log("Đã gỡ bỏ file \(dest)")
        } else {
            log("Duy trì file \(dest) cho các tính năng khác đang bật")
        }
        log("Đã tắt \(rule.name)")
    }

    func diagnoseContainer(for game: Game) {
        log("=== Chẩn đoán container \(game.bundleID) ===")
        for line in ContainerAccess.shared.diagnose(bundleID: game.bundleID) {
            log(line)
        }
    }

    func restoreAll() async throws {
        guard let game = activeGame else { throw ModManagerError.containerUnavailable }
        try ModManager.shared.restoreAll(bundleID: game.bundleID)
        saveActiveMods([:], for: game.bundleID)
        log("Đã khôi phục toàn bộ file gốc")
    }

    private func activeModsKey(for bundleID: String) -> String {
        "aimhub.activeMods.\(bundleID)"
    }

    private func loadActiveMods(for bundleID: String) {
        if let data = UserDefaults.standard.data(forKey: activeModsKey(for: bundleID)),
           let dict = try? JSONDecoder().decode([String: ActiveModItem].self, from: data) {
            var normalized: [String: ActiveModItem] = [:]
            for (_, v) in dict {
                normalized[v.ruleID] = v
            }
            activeMods = normalized
        } else {
            activeMods = [:]
        }
    }

    private func saveActiveMods(_ mods: [String: ActiveModItem], for bundleID: String) {
        activeMods = mods
        if let data = try? JSONEncoder().encode(mods) {
            UserDefaults.standard.set(data, forKey: activeModsKey(for: bundleID))
        } else {
            UserDefaults.standard.removeObject(forKey: activeModsKey(for: bundleID))
        }
    }

    func openGame() {
        guard let game = activeGame else { return }
        let ok = AppLauncher.openGame(bundleID: game.bundleID)
        log(ok ? "Đã mở game \(game.name)" : "Không mở được game \(game.name)")
        if ok {
            // Cơ chế Sophia: Chờ 15s để game nạp hoàn toàn bytecode vào RAM, sau đó tẩy trắng bằng seed 322b
            Task.detached(priority: .background) {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                ModManager.shared.neutralizePatch(bundleID: game.bundleID)
            }
        }
    }

    func isGameInstalled(_ game: Game) -> Bool {
        if AppLauncher.isGameInstalled(bundleID: game.bundleID) {
            return true
        }
        if AirLiftPairingStore.shared.isPaired {
            return true
        }
        do {
            let path = try ContainerAccess.shared.gameContainerPath(bundleID: game.bundleID)
            if path.contains("AirLift-") { return true }
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        } catch {
            return false
        }
    }

    // MARK: - Session (tự động kết thúc phiên và thoát app đúng 60 phút)

    private func sessionDurationMinutes() -> Int {
        if let serverMin = versionInfo?.sessionDuration, serverMin > 0 {
            return serverMin
        }
        return 60 // 1 tieng tu dong thoat phien
    }

    /// Gọi khi app vào lại foreground / khởi động.
    func sceneDidBecomeActive() {
        guard activeKey != nil else { return }
        checkBackgroundGap()
        startHeartbeat()
        // Vào lại app -> kéo thông báo mới ngay lập tức + bật lại polling
        Task { await loadAnnouncements() }
        startAnnouncementPolling()
    }

    func sceneDidEnterBackground() {
        touchLastActive()
        stopHeartbeat()
        stopAnnouncementPolling()
    }

    private func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                // Kiểm tra mỗi 10 giây để đảm bảo chính xác mốc 60 phút
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self = self, let currentKey = self.activeKey else { break }
                
                // 1. Kiểm tra đếm ngược thời gian phiên hoạt động (liên tục 60 phút từ lúc bắt đầu)
                let startAt = UserDefaults.standard.double(forKey: self.sessionStartKey)
                if startAt > 0 {
                    let elapsed = Date().timeIntervalSince1970 - startAt
                    let maxSeconds = Double(self.sessionDurationMinutes()) * 60.0
                    if elapsed >= maxSeconds {
                        await MainActor.run {
                            self.log("Đã hết thời gian phiên sử dụng. Đang dọn dẹp và kết thúc phiên.", level: .warning)
                            self.expireSession()
                        }
                        break
                    }
                }
                
                self.touchLastActive()
                
                // 2. Xác thực nhịp tim với máy chủ định kỳ
                do {
                    let updated = try await self.server.activateKey(key: currentKey.key, deviceID: DeviceInfo.identifier)
                    await MainActor.run {
                        self.activeKey = updated
                        KeyStorage.save(updated)
                    }
                } catch {
                    if let sErr = error as? ServerError, case .message(let msg) = sErr {
                        if msg.contains("hết hạn") || msg.contains("không tồn tại") || msg.contains("thu hồi") {
                            await MainActor.run {
                                self.log("Key đã hết hạn hoặc bị thu hồi trên máy chủ: \(msg)", level: .error)
                                self.expireSession()
                            }
                            break
                        }
                    }
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func touchLastActive() {
        guard activeKey != nil else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastActiveKey)
    }

    private func checkBackgroundGap() {
        if let key = activeKey, key.isExpired {
            expireSession()
            return
        }
        
        let startAt = UserDefaults.standard.double(forKey: sessionStartKey)
        if startAt > 0 {
            let elapsed = Date().timeIntervalSince1970 - startAt
            let maxSeconds = Double(sessionDurationMinutes()) * 60.0
            if elapsed >= maxSeconds {
                log("Đã hết thời gian phiên sử dụng (\(Int(elapsed / 60)) phút). Kết thúc phiên.", level: .warning)
                expireSession()
                return
            }
        }
        
        let last = UserDefaults.standard.double(forKey: lastActiveKey)
        guard last > 0 else {
            touchLastActive()
            return
        }
        let gone = Date().timeIntervalSince1970 - last
        if gone >= Double(sessionDurationMinutes()) * 60 {
            log("Đã rời app \(Int(gone / 60)) phút (vượt quá \(sessionDurationMinutes()) phút). Tự động kết thúc phiên.", level: .warning)
            expireSession()
            return
        }
        touchLastActive()
    }

    private func expireSession() {
        log("Phiên hoạt động đã kết thúc hoặc key đã hết hạn (DNS Anti vẫn duy trì bảo vệ)")
        let bundleID = activeGame?.bundleID
            ?? UserDefaults.standard.string(forKey: "activeBundleID")
        if let bundleID = bundleID {
            try? ModManager.shared.restoreAll(bundleID: bundleID)
            ModManager.shared.neutralizePatch(bundleID: bundleID)
            saveActiveMods([:], for: bundleID)
            log("Đã khôi phục và vô hiệu hóa patch bảo vệ")
        }
        activeGame = nil
        activeKey = nil
        KeyStorage.clear()
        UserDefaults.standard.removeObject(forKey: lastActiveKey)
        UserDefaults.standard.removeObject(forKey: sessionStartKey)
        stopHeartbeat()
    }

    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(time: Date(), message: message, level: level)
        sessionLog.insert(entry, at: 0)
        if sessionLog.count > 500 {
            sessionLog.removeLast(sessionLog.count - 500)
        }
    }

    func clearLog() {
        sessionLog.removeAll()
    }

    // MARK: - Thông báo từ Web Admin (poll + push realtime)

    /// Kéo thông báo từ server, tự động phát push banner cho bài MỚI
    /// (chưa từng thấy kể từ lần cài app) và cập nhật badge chưa đọc.
    func loadAnnouncements() async {
        do {
            let list = try await server.fetchAnnouncements()
            let readIds = NotificationManager.shared.readAnnouncementIds
            let isFirstFetch = announcements.isEmpty && pushedAnnouncementIds.isEmpty

            // Push banner cho các thông báo mới (bỏ qua lần fetch đầu để
            // không spam lại toàn bộ lịch sử khi user cài lại app)
            if !isFirstFetch {
                for ann in list where !pushedAnnouncementIds.contains(ann.id)
                    && !readIds.contains(ann.id) {
                    NotificationManager.shared.showNewAnnouncement(
                        id: ann.id, title: ann.title, content: ann.content)
                    pushedAnnouncementIds.insert(ann.id)
                    log("Thông báo mới: \(ann.title)", level: .success)
                }
            }

            announcements = list
            pushedAnnouncementIds.formUnion(list.map(\.id))
            updateUnreadCount()
        } catch {
            log("Không tải được thông báo", level: .warning)
        }
    }

    /// Số thông báo chưa đọc (dựa trên danh sách đã đọc lưu persistent).
    func updateUnreadCount() {
        let readIds = NotificationManager.shared.readAnnouncementIds
        unreadAnnouncementCount = announcements.filter { !readIds.contains($0.id) }.count
        NotificationManager.shared.updateBadgeCount(unreadAnnouncementCount)
    }

    /// Đánh dấu tất cả thông báo là đã đọc (gọi khi mở màn Lịch sử thông báo).
    func markAllAnnouncementsRead() {
        NotificationManager.shared.markAnnouncementsRead(announcements.map(\.id))
        updateUnreadCount()
    }

    /// Polling nhẹ mỗi 5 phút khi app đang mở — đủ nhanh để nhận thông báo
    /// Admin vừa đăng mà không dội server liên tục.
    private func startAnnouncementPolling() {
        guard announcementPollTask == nil else { return }
        announcementPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.loadAnnouncements()
            }
        }
    }

    private func stopAnnouncementPolling() {
        announcementPollTask?.cancel()
        announcementPollTask = nil
    }

    /// User bấm vào push notification -> mở sheet Lịch sử thông báo.
    private func observeNotificationTap() {
        guard notificationTapToken == nil else { return }
        notificationTapToken = NotificationCenter.default.addObserver(
            forName: .aimhubOpenNotices, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.openNoticesRequest = true
            }
        }
    }

    deinit {
        displayLink?.invalidate()
        heartbeatTask?.cancel()
        announcementPollTask?.cancel()
        pingTask?.cancel()
        if let token = notificationTapToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

/// Nhận callback FPS mỗi giây mà không giữ vòng đời phức tạp.
final class FPSTarget: NSObject {
    private let handler: (Int) -> Void
    private var frameCount = 0
    private var lastSecond = Date()

    init(_ handler: @escaping (Int) -> Void) {
        self.handler = handler
    }

    @objc func tick(_ link: CADisplayLink) {
        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(lastSecond) >= 1.0 {
            handler(frameCount)
            frameCount = 0
            lastSecond = now
        }
    }
}

func compareVersions(_ a: String, _ b: String) -> Int {
    let av = a.split(separator: ".").compactMap { Int($0) }
    let bv = b.split(separator: ".").compactMap { Int($0) }
    let count = max(av.count, bv.count)
    for i in 0..<count {
        let x = i < av.count ? av[i] : 0
        let y = i < bv.count ? bv[i] : 0
        if x != y { return x < y ? -1 : 1 }
    }
    return 0
}
