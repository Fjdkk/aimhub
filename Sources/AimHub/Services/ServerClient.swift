import Foundation

public enum ServerError: Error, CustomStringConvertible {
    case invalidURL
    case http(Int)
    case decoding(String)
    case message(String)

    public var description: String {
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

public struct ProjectDetail: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let game: String
    public let bundleID: String
    public let rules: [RuleDetail]

    public var id: String { name }
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

    public var id: String { ruleID }
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

public struct LogEntry: Identifiable, Hashable {
    public let id = UUID()
    public let time: Date
    public let message: String
}

public enum Language: String, Codable {
    case vietnamese
    case english
}

public final class ServerClient {
    public static let shared = ServerClient()

    private let baseURL: String

    public init(baseURL: String = ServerConfig.baseURL) {
        self.baseURL = baseURL
    }

    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw ServerError.invalidURL
        }
        return url
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
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

    public func fetchGames() async throws -> [Game] {
        let wrapped: GamesResponse = try await get("/api/games")
        return wrapped.games
    }

    public func activateKey(key: String, deviceID: String) async throws -> KeyInfo {
        let url = try makeURL("/api/key/activate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let body: [String: String] = ["key": key, "device_id": deviceID]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            guard http.statusCode == 200 else {
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = obj["detail"] as? String {
                    throw ServerError.message(translate(detail))
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

    public func downloadRuleFile(ruleID: String) async throws -> Data {
        let url = try makeURL("/api/rules/\(ruleID)/file")
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            guard http.statusCode == 200 else { throw ServerError.http(http.statusCode) }
        }
        return data
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