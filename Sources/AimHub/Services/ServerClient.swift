import Foundation

public enum ServerError: Error, LocalizedError {
    case invalidURL
    case http(Int)
    case decoding(String)
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL không hợp lệ"
        case .http(let c): return "Lỗi server (\(c))"
        case .decoding(let m): return "Lỗi dữ liệu: \(m)"
        case .message(let m): return m
        }
    }
}

public struct Game: Codable, Identifiable, Hashable {
    public let game: String
    public let bundleID: String
    public let projects: [ProjectSummary]?

    public var id: String { bundleID }
    public var name: String { game }
}

public struct ProjectSummary: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let rulesCount: Int
    public let rules: [RuleSummary]?

    enum CodingKeys: String, CodingKey {
        case id, name
        case rulesCount = "rules_count"
        case rules
    }
}

public struct RuleSummary: Codable, Identifiable, Hashable {
    public let ruleID: String
    public let name: String
    public let slot: String?
    public let enabled: Bool?
    public let size: Int?
    public let bundleID: String?

    public var id: String { ruleID }
}

public struct TabDetail: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let order: Int?
    public let visible: Bool?
}

public struct MenuSchema: Codable, Hashable {
    public let sections: [MenuSection]
    public let actionButton: MenuActionButton?

    enum CodingKeys: String, CodingKey {
        case sections
        case actionButton = "action_button"
    }

    public static var defaultSchema: MenuSchema {
        MenuSchema(
            sections: [
                MenuSection(
                    title: "ESP",
                    items: [
                        MenuItem(type: "toggle", key: "esp_box", configKey: "hub_st", bitmask: 1, title: "ESP Box", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "esp_line", configKey: "hub_st", bitmask: 2, title: "ESP Line", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "esp_name", configKey: "hub_st", bitmask: 65536, title: "ESP Name", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "esp_distance", configKey: "hub_st", bitmask: 32768, title: "ESP Distance", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "esp_health", configKey: "hub_st", bitmask: 512, title: "ESP Health Bar", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "esp_skeleton", configKey: "hub_st", bitmask: 131072, title: "ESP Skeleton", min: nil, max: nil, step: nil, options: nil, defaultValue: "false")
                    ]
                ),
                MenuSection(
                    title: "AIM BOT",
                    items: [
                        MenuItem(type: "toggle", key: "aim_fov_circle", configKey: "hub_fov_circle", bitmask: nil, title: "Vòng Tròn FOV (FOV Circle)", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "slider", key: "aim_fov", configKey: "hub_fov", bitmask: nil, title: "Bán Kính FOV (Radius)", min: 10, max: 360, step: 5, options: nil, defaultValue: "65"),
                        MenuItem(type: "toggle", key: "aim_bot", configKey: "hub_aim", bitmask: nil, title: "Aim Bot", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "aim_silent", configKey: "hub_sil", bitmask: nil, title: "Aim Silent", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "no_recoil", configKey: "hub_nm", bitmask: nil, title: "No Recoil", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "segmented", key: "aim_target", configKey: "hub_tab", bitmask: nil, title: "Vị trí ngắm (Target)", min: nil, max: nil, step: nil, options: ["HEAD", "NECK", "BODY"], defaultValue: "HEAD")
                    ]
                ),
                MenuSection(
                    title: "SPEED",
                    items: [
                        MenuItem(type: "toggle", key: "speed_run", configKey: "hub_run_speed", bitmask: nil, title: "Run Speed (Tăng tốc chạy)", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "speed_crouch", configKey: "hub_crouch_speed", bitmask: nil, title: "Crouch Speed (Tăng tốc bò/ngồi)", min: nil, max: nil, step: nil, options: nil, defaultValue: "false"),
                        MenuItem(type: "toggle", key: "speed_sky", configKey: "hub_sky_speed", bitmask: nil, title: "Sky Speed (Nhảy dù siêu tốc)", min: nil, max: nil, step: nil, options: nil, defaultValue: "false")
                    ]
                ),
                MenuSection(
                    title: "HEAL & UTILITY",
                    items: [
                        MenuItem(type: "toggle", key: "heal_fast", configKey: "hub_heal_fast", bitmask: nil, title: "Heal Fast (Cắn máu / Nuốt nấm tức thì)", min: nil, max: nil, step: nil, options: nil, defaultValue: "false")
                    ]
                )
            ],
            actionButton: MenuActionButton(
                injectText: "Injector",
                uninjectText: "Uninjector",
                injectingText: "Đang Inject...",
                uninjectingText: "Đang gỡ bỏ...",
                successInjectToast: "Đã nạp Injector thành công!",
                successUninjectToast: "Đã gỡ bỏ Injector thành công!"
            )
        )
    }
}

public struct MenuSection: Codable, Hashable, Identifiable {
    public var id: String { title }
    public let title: String
    public let items: [MenuItem]
}

public struct MenuItem: Codable, Hashable, Identifiable {
    public var id: String { key }
    public let type: String // "toggle", "slider", "segmented"
    public let key: String
    public let configKey: String
    public let bitmask: Int?
    public let title: String
    public let min: Double?
    public let max: Double?
    public let step: Double?
    public let options: [String]?
    public let defaultValue: String?

    enum CodingKeys: String, CodingKey {
        case type, key, bitmask, title, min, max, step, options
        case configKey = "config_key"
        case defaultValue = "default"
    }

    public init(type: String, key: String, configKey: String, bitmask: Int? = nil, title: String, min: Double? = nil, max: Double? = nil, step: Double? = nil, options: [String]? = nil, defaultValue: String? = nil) {
        self.type = type
        self.key = key
        self.configKey = configKey
        self.bitmask = bitmask
        self.title = title
        self.min = min
        self.max = max
        self.step = step
        self.options = options
        self.defaultValue = defaultValue
    }
}

public struct MenuActionButton: Codable, Hashable {
    public let injectText: String?
    public let uninjectText: String?
    public let injectingText: String?
    public let uninjectingText: String?
    public let successInjectToast: String?
    public let successUninjectToast: String?

    enum CodingKeys: String, CodingKey {
        case injectText = "inject_text"
        case uninjectText = "uninject_text"
        case injectingText = "injecting_text"
        case uninjectingText = "uninjecting_text"
        case successInjectToast = "success_inject_toast"
        case successUninjectToast = "success_uninject_toast"
    }

    public init(injectText: String? = nil, uninjectText: String? = nil, injectingText: String? = nil, uninjectingText: String? = nil, successInjectToast: String? = nil, successUninjectToast: String? = nil) {
        self.injectText = injectText
        self.uninjectText = uninjectText
        self.injectingText = injectingText
        self.uninjectingText = uninjectingText
        self.successInjectToast = successInjectToast
        self.successUninjectToast = successUninjectToast
    }
}

public struct ProjectDetail: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let game: String
    public let bundleID: String
    public let tabs: [TabDetail]?
    public let rules: [RuleDetail]
    public let menuSchema: MenuSchema?

    enum CodingKeys: String, CodingKey {
        case id, name, game, bundleID, tabs, rules
        case menuSchema = "menu_schema"
    }
}

public struct RuleDetail: Codable, Identifiable, Hashable {
    public let ruleID: String
    public let name: String
    public let slot: String?
    public let destination: String?
    public let replacement: String?
    public let original: String?
    public let bundleID: String?
    public let enabled: Bool?
    public let size: Int?
    public let tabID: String?
    public let tabName: String?
    public let tabOrder: Int?
    public let tabVisible: Bool?
    public let mode: String?
    public let conflictGroup: String?

    public var id: String { ruleID }

    enum CodingKeys: String, CodingKey {
        case ruleID
        case name
        case slot
        case destination
        case replacement
        case original
        case bundleID
        case enabled
        case size
        case tabID = "tab_id"
        case tabName = "tab_name"
        case tabOrder = "tab_order"
        case tabVisible = "tab_visible"
        case mode
        case conflictGroup = "conflict_group"
    }
}

public struct KeyInfo: Codable, Hashable {
    public let key: String
    public let deviceID: String?
    public let expires: String?
    public let mods: [String]?

    enum CodingKeys: String, CodingKey {
        case key
        case deviceID = "device_id"
        case expires
        case mods
    }
}

public struct Announcement: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let content: String?
    public let date: String?
}

public struct VersionInfo: Codable, Hashable {
    public let latestVersion: String
    public let minVersion: String
    public let iosSupported: [String]
    public let sessionDuration: Int

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case minVersion = "min_version"
        case iosSupported = "ios_supported"
        case sessionDuration = "session_duration"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        latestVersion = try c.decodeIfPresent(String.self, forKey: .latestVersion) ?? "1.0"
        minVersion = try c.decodeIfPresent(String.self, forKey: .minVersion) ?? "1.0"
        iosSupported = try c.decodeIfPresent([String].self, forKey: .iosSupported) ?? []
        sessionDuration = try c.decodeIfPresent(Int.self, forKey: .sessionDuration) ?? 60
    }

    public init(latestVersion: String, minVersion: String,
                iosSupported: [String], sessionDuration: Int) {
        self.latestVersion = latestVersion
        self.minVersion = minVersion
        self.iosSupported = iosSupported
        self.sessionDuration = sessionDuration
    }
}

public enum LogLevel: String, Codable, Hashable {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

public struct LogEntry: Identifiable, Hashable {
    public let id = UUID()
    public let time: Date
    public let message: String
    public let level: LogLevel

    public init(time: Date, message: String, level: LogLevel = .info) {
        self.time = time
        self.message = message
        self.level = level
    }
}

public enum Language: String, Codable {
    case vietnamese
    case english
}

public final class ServerClient: @unchecked Sendable {
    public static let shared = ServerClient()

    private let baseURL: String
    private let session: URLSession

    public init(baseURL: String = ServerConfig.baseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    private func makeURL(_ path: String) throws -> URL {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let cleanPath = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: base + cleanPath) else {
            throw ServerError.invalidURL
        }
        return url
    }

    private func executeWithRetry<T>(
        maxRetries: Int = 2,
        initialDelay: Double = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                let canRetry: Bool
                if let urlErr = error as? URLError {
                    switch urlErr.code {
                    case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost, .notConnectedToInternet:
                        canRetry = true
                    default:
                        canRetry = false
                    }
                } else {
                    canRetry = false
                }

                if canRetry && attempt < maxRetries {
                    let delaySeconds = initialDelay * (attempt == 0 ? 1.0 : 2.0)
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    continue
                }
                throw wrapError(error)
            }
        }
        throw wrapError(lastError ?? ServerError.message("Lỗi kết nối máy chủ"))
    }

    private func wrapError(_ error: Error) -> Error {
        if let serverError = error as? ServerError {
            return serverError
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return ServerError.message("Hết thời gian chờ kết nối máy chủ. Vui lòng kiểm tra lại 4G/Wi-Fi hoặc tắt VPN nếu đang bật.")
            case .notConnectedToInternet:
                return ServerError.message("Không có kết nối Internet. Vui lòng bật Wi-Fi/4G và cho phép ứng dụng truy cập dữ liệu mạng.")
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return ServerError.message("Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng hoặc thử đổi mạng khác.")
            case .networkConnectionLost:
                return ServerError.message("Kết nối mạng bị gián đoạn. Vui lòng thử lại.")
            default:
                return ServerError.message("Lỗi kết nối: \(urlError.localizedDescription)")
            }
        }
        return error
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await executeWithRetry {
            let url = try self.makeURL(path)
            var request = URLRequest(url: url)
            request.timeoutInterval = 25
            let (data, response) = try await self.session.data(for: request)
            if let http = response as? HTTPURLResponse {
                guard http.statusCode == 200 else {
                    throw ServerError.http(http.statusCode)
                }
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ServerError.decoding(error.localizedDescription)
            }
        }
    }

    public func fetchGames() async throws -> [Game] {
        let wrapped: GamesResponse = try await get("/api/games")
        return wrapped.games
    }

    public func activateKey(key: String, deviceID: String) async throws -> KeyInfo {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return try await executeWithRetry(maxRetries: 2, initialDelay: 1.0) {
            let url = try self.makeURL("/api/key/activate")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 25
            let body: [String: String] = ["key": cleanKey, "device_id": deviceID]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await self.session.data(for: request)
            if let http = response as? HTTPURLResponse {
                guard http.statusCode == 200 else {
                    if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = obj["detail"] as? String {
                        throw ServerError.message(self.translate(detail))
                    }
                    throw ServerError.http(http.statusCode)
                }
            }
            do {
                return try JSONDecoder().decode(KeyInfo.self, from: data)
            } catch {
                throw ServerError.decoding(error.localizedDescription)
            }
        }
    }

    public func fetchAnnouncements() async throws -> [Announcement] {
        let wrapped: AnnouncementsResponse = try await get("/api/announcements")
        return wrapped.announcements
    }

    public func fetchProject(projectID: String) async throws -> ProjectDetail {
        try await get("/api/projects/\(projectID)")
    }

    public func fetchVersion() async throws -> VersionInfo {
        try await get("/api/version")
    }

    /// Đo độ trễ mạng (ms) bằng request nhẹ tới /api/version.
    public func ping() async -> Int? {
        let url: URL
        do {
            url = try makeURL("/api/version")
        } catch {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let start = Date()
        do {
            _ = try await session.data(for: request)
            return Int(Date().timeIntervalSince(start) * 1000)
        } catch {
            return nil
        }
    }

    public func downloadRuleFile(ruleID: String, activeSlots: [String]? = nil, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        try await executeWithRetry(maxRetries: 2, initialDelay: 1.5) {
            var path = "/api/rules/\(ruleID)/file"
            var qItems: [URLQueryItem] = queryItems ?? []
            if let slots = activeSlots, !slots.isEmpty {
                qItems.append(URLQueryItem(name: "slots", value: slots.joined(separator: ",")))
            }
            if !qItems.isEmpty {
                var components = URLComponents(string: path)
                components?.queryItems = qItems
                if let full = components?.string {
                    path = full
                }
            }
            let url = try self.makeURL(path)
            var request = URLRequest(url: url)
            request.timeoutInterval = 45
            if let key = KeyStorage.load()?.key {
                request.setValue(key, forHTTPHeaderField: "X-License-Key")
            }
            request.setValue(DeviceInfo.identifier, forHTTPHeaderField: "X-Device-ID")
            let (data, response) = try await self.session.data(for: request)
            if let http = response as? HTTPURLResponse {
                guard http.statusCode == 200 else { throw ServerError.http(http.statusCode) }
            }
            return data
        }
    }

    public func fetchMenuSchema(tabID: String = "tab_menu_aimhub") async -> MenuSchema {
        do {
            let schema: MenuSchema = try await get("/api/menu-schema/\(tabID)")
            return schema
        } catch {
            return MenuSchema.defaultSchema
        }
    }

    private func translate(_ detail: String) -> String {
        switch detail {
        case "license.key_not_found": return "Key không tồn tại"
        case "license.expired": return "Key đã hết hạn"
        case "license.device_mismatch": return "Key đã được kích hoạt trên thiết bị khác"
        default: return detail
        }
    }
}

private struct GamesResponse: Decodable {
    let games: [Game]
}

private struct AnnouncementsResponse: Decodable {
    let announcements: [Announcement]
}

public enum ServerConfig {
    public static var baseURL: String {
        guard let v = Bundle.main.object(forInfoDictionaryKey: "AimHubServerBaseURL") as? String,
              !v.isEmpty else {
            return "https://mods.gamesieure.io.vn"
        }
        return v
    }
}