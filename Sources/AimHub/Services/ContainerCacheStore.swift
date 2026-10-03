import Foundation

/// Quản lý bộ nhớ đệm (Cache) đường dẫn Container của từng game.
/// Giúp app không cần quét lại ổ đĩa nhiều lần, kích hoạt mod tức thì dưới 0.01s.
public final class ContainerCacheStore {
    public static let shared = ContainerCacheStore()
    
    private let cacheKeyPrefix = "aimhub.container.cache."
    private let timestampKeyPrefix = "aimhub.container.cache.time."
    
    // Cache tồn tại trong 24 giờ trước khi cần kiểm tra lại
    private let cacheTTL: TimeInterval = 86400
    
    private init() {}
    
    public func getCachedPath(for bundleID: String) -> String? {
        let key = cacheKeyPrefix + bundleID
        let timeKey = timestampKeyPrefix + bundleID
        
        guard let path = UserDefaults.standard.string(forKey: key) else {
            return nil
        }
        
        let savedTime = UserDefaults.standard.double(forKey: timeKey)
        if savedTime > 0 && (Date().timeIntervalSince1970 - savedTime) > cacheTTL {
            // Cache hết hạn
            clearCache(for: bundleID)
            return nil
        }
        
        // Xác minh đường dẫn vẫn tồn tại trên đĩa
        if POSIXFile.isDirectory(path) {
            return path
        } else {
            clearCache(for: bundleID)
            return nil
        }
    }
    
    public func setCachedPath(_ path: String, for bundleID: String) {
        let key = cacheKeyPrefix + bundleID
        let timeKey = timestampKeyPrefix + bundleID
        
        UserDefaults.standard.set(path, forKey: key)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeKey)
    }
    
    public func clearCache(for bundleID: String) {
        let key = cacheKeyPrefix + bundleID
        let timeKey = timestampKeyPrefix + bundleID
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: timeKey)
    }
    
    public func clearAllCaches() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix(cacheKeyPrefix) || key.hasPrefix(timestampKeyPrefix) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
