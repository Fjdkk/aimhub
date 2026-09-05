import Foundation
import SwiftUI
import UIKit

public struct ActiveModItem: Codable, Equatable, Hashable {
    public let ruleID: String
    public let name: String
    public let destination: String

    public init(ruleID: String, name: String, destination: String) {
        self.ruleID = ruleID
        self.name = name
        self.destination = destination
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var activeKey: KeyInfo?
    @Published var activeGame: Game?
    @Published var activeMods: [String: ActiveModItem] = [:] // key: destination path

    var activeModID: String? {
        activeMods.values.first?.ruleID
    }

    var activeModNames: [String] {
        activeMods.values.map { $0.name }
    }

    func isModActive(ruleID: String) -> Bool {
        activeMods.values.contains(where: { $0.ruleID == ruleID })
    }

    func activeMod(forDestination destination: String) -> ActiveModItem? {
        activeMods[destination]
    }

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

    private let server = ServerClient.shared
    private var started = false
    private let lastActiveKey = "aimhub.session.lastActiveAt"
    private let notificationsKey = "aimhub.notificationsEnabled"
    private let languageKey = "aimhub.language"
    private var heartbeatTask: Task<Void, Never>?
    private var announcementPollTask: Task<Void, Never>?
    private var displayLink: CADisplayLink?
    /// Lưu id thông báo đã xử lý push trong phiên này để không push lại.
    private var pushedAnnouncementIds: Set<String> = []
    private var notificationTapToken: NSObjectProtocol?

    init() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: notificationsKey)
        if let raw = UserDefaults.standard.string(forKey: languageKey),
           let lang = Language(rawValue: raw) {
            language = lang
        } else {
            language = .vietnamese
        }
        L10n.current = language
        startFPSMonitor()
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
        activeKey = KeyStorage.load()
        NotificationManager.shared.configure()
        checkVersion()
        if activeKey != nil {
            checkBackgroundGap()
            startHeartbeat()
        }
        observeNotificationTap()
        Task { await loadAnnouncements() }
        startAnnouncementPolling()
    }

    func activateKey(_ key: String) async throws {
        let deviceID = DeviceInfo.identifier
        let info = try await server.activateKey(key: key, deviceID: deviceID)
        activeKey = info
        KeyStorage.save(info)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastActiveKey)
        log("Kích hoạt key thành công", level: .success)
    }

    func clearKey() {
        activeKey = nil
        KeyStorage.clear()
        UserDefaults.standard.removeObject(forKey: lastActiveKey)
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
        
        // Nếu cùng file destination đang có mod khác bật (vd: đang bật Aim Body mà bấm Aim Neck)
        // -> Khôi phục file gốc của destination đó trước
        if let existing = activeMods[dest], existing.ruleID != rule.ruleID {
            try? ModManager.shared.restoreFile(relativePath: dest, bundleID: game.bundleID)
            log("Tự động tắt \(existing.name) do cùng can thiệp file")
        }

        try ModManager.shared.installMod(mod, bundleID: game.bundleID)
        var current = activeMods
        current[dest] = ActiveModItem(ruleID: rule.ruleID, name: rule.name, destination: dest)
        saveActiveMods(current, for: game.bundleID)
        log("Đã bật \(rule.name)")
    }

    func turnOffMod(_ rule: RuleDetail) async throws {
        guard let game = activeGame else { throw ModManagerError.containerUnavailable }
        let dest = rule.destination ?? "Documents/\(rule.ruleID).bin"
        try ModManager.shared.restoreFile(relativePath: dest, bundleID: game.bundleID)
        var current = activeMods
        current.removeValue(forKey: dest)
        saveActiveMods(current, for: game.bundleID)
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
            activeMods = dict
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
    }

    func isGameInstalled(_ game: Game) -> Bool {
        if AppLauncher.isGameInstalled(bundleID: game.bundleID) {
            return true
        }
        do {
            let path = try ContainerAccess.shared.gameContainerPath(bundleID: game.bundleID)
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        } catch {
            log("Check game \(game.bundleID) thất bại: \(error.localizedDescription)")
            log("App phát hiện: \(AppLauncher.debugGameApps().joined(separator: ", "))")
            return false
        }
    }

    // MARK: - Session (auto logout khi rời app quá lâu)

    private func sessionDurationMinutes() -> Int {
        versionInfo?.sessionDuration ?? 60
    }

    /// Gọi khi app vào lại foreground / khởi động. Đếm thời gian rời app,
    /// không đếm thời gian user đang ở trong app.
    func sceneDidBecomeActive() {
        guard activeKey != nil else { return }
        checkBackgroundGap()
        startHeartbeat()
        // Vào lại app -> kéo thông báo mới ngay lập tức + bật lại polling
        Task { await loadAnnouncements() }
        startAnnouncementPolling()
    }

    func sceneDidEnterBackground() {
        stopHeartbeat()
        stopAnnouncementPolling()
    }

    private func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                self?.touchLastActive()
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
        let last = UserDefaults.standard.double(forKey: lastActiveKey)
        guard last > 0 else {
            touchLastActive()
            return
        }
        let gone = Date().timeIntervalSince1970 - last
        if gone >= Double(sessionDurationMinutes()) * 60 {
            expireSession()
        }
    }

    private func expireSession() {
        log("Phiên hoạt động đã hết hạn")
        let bundleID = activeGame?.bundleID
            ?? UserDefaults.standard.string(forKey: "activeBundleID")
        if let bundleID = bundleID, !activeMods.isEmpty {
            try? ModManager.shared.restoreAll(bundleID: bundleID)
            saveActiveMods([:], for: bundleID)
            log("Đã khôi phục file gốc khi hết phiên")
        }
        activeGame = nil
        activeKey = nil
        KeyStorage.clear()
        UserDefaults.standard.removeObject(forKey: lastActiveKey)
        stopHeartbeat()
    }

    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(time: Date(), message: message, level: level)
        sessionLog.insert(entry, at: 0)
        if sessionLog.count > 200 {
            sessionLog.removeLast(sessionLog.count - 200)
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
            self?.openNoticesRequest = true
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