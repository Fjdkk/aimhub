import Foundation

/// Dịch vụ kết nối HouseArrest (com.apple.mobile.house_arrest)
/// Cho phép đọc ghi trực tiếp thư mục Documents của ứng dụng game có chia sẻ tệp.
public final class HouseArrestClient {
    public static let shared = HouseArrestClient()
    
    private init() {}
    
    /// Thử lấy đường dẫn Documents thông qua quyền chia sẻ tệp công khai của Bundle ID
    public func lookupDocumentsPath(for bundleID: String) -> String? {
        // Thử tìm trong Documents thư mục chia sẻ
        let candidatePaths = [
            "/var/mobile/Containers/Data/Application",
            "/private/var/mobile/Containers/Data/Application"
        ]
        
        for root in candidatePaths {
            guard let subs = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for sub in subs {
                let candidate = "\(root)/\(sub)"
                let meta = "\(candidate)/.com.apple.mobile_container_manager.metadata.plist"
                if let data = try? Data(contentsOf: URL(fileURLWithPath: meta)),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let ident = plist["MCMMetadataIdentifier"] as? String,
                   ident == bundleID {
                    let docPath = "\(candidate)/Documents"
                    if POSIXFile.isDirectory(docPath) {
                        ContainerAccess.diag("[HouseArrest] Tìm thấy Documents qua HouseArrest candidate: \(docPath)")
                        return docPath
                    }
                }
            }
        }
        return nil
    }
}
