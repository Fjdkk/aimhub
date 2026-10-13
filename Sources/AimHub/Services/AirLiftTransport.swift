import Foundation
import Darwin

public final class AirLiftTransport {
    public static let shared = AirLiftTransport()
    
    private init() {}
    
    /// Kiểm tra xem chế độ AirLift có đang sẵn sàng để đọc ghi không
    public var isAvailable: Bool {
        return AirLiftPairingStore.shared.isPaired
    }
    
    /// Ghi nội dung tệp vào container thông qua quyền AirLift AFC
    public func writeAppFile(data: Data, bundleID: String, relativePath: String, directPath: String? = nil) throws {
        // 1. Thử ghi trực tiếp nếu có đường dẫn tuyệt đối (bỏ qua nếu là kênh ảo AirLift)
        if let directPath = directPath, !directPath.contains("AirLift-") && !AirLiftPairingStore.shared.isPaired {
            do {
                let dir = (directPath as NSString).deletingLastPathComponent
                try? POSIXFile.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try POSIXFile.write(data: data, to: directPath)
                ContainerAccess.diag("[AirLift] ✅ Ghi trực tiếp POSIX thành công: \(directPath) (\(data.count) bytes)")
                return
            } catch {
                ContainerAccess.diag("[AirLift] ⚠️ Ghi trực tiếp POSIX thất bại (\(error.localizedDescription)), chuyển sang kênh ghép đôi AirLift AFC...")
            }
        }
        
        // 2. Sử dụng kênh ghép đôi AirLift AFC qua FFI
        guard let pairingPath = AirLiftPairingStore.shared.pairingFilePath,
              FileManager.default.fileExists(atPath: pairingPath) else {
            throw POSIXFileError.io("Chưa có hồ sơ ghép đôi AirLift (.mobiledevicepairing). Hãy vào Cài đặt -> Ghép đôi trước.")
        }
        
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        let rc = data.withUnsafeBytes { rawBuf -> Int32 in
            let ptr = rawBuf.bindMemory(to: UInt8.self).baseAddress
            return stikpair_write_app_file(
                pairingPath,
                bundleID,
                relativePath,
                ptr,
                data.count,
                &errPtr
            )
        }
        
        if rc != 0 {
            let errMsg: String
            if let errPtr = errPtr {
                errMsg = String(cString: errPtr)
                stikpair_free_string(errPtr)
            } else {
                errMsg = "Mã lỗi AirLift FFI: \(rc)"
            }
            ContainerAccess.diag("[AirLift] ❌ Ghi file qua AirLift AFC thất bại: \(errMsg)")
            throw POSIXFileError.io("AirLift AFC: \(errMsg)")
        }
        
        ContainerAccess.diag("[AirLift] ✅ Đã truyền và dán tệp thành công qua AirLift AFC: \(relativePath) (\(data.count) bytes)")
    }
    
    /// Xóa tệp qua AirLift AFC
    public func removeAppFile(bundleID: String, relativePath: String, directPath: String? = nil) throws {
        if let directPath = directPath, !directPath.contains("AirLift-"), POSIXFile.exists(directPath) {
            try? POSIXFile.remove(directPath)
        }
        
        if let pairingPath = AirLiftPairingStore.shared.pairingFilePath,
           FileManager.default.fileExists(atPath: pairingPath) {
            var errPtr: UnsafeMutablePointer<CChar>? = nil
            let rc = stikpair_remove_app_file(pairingPath, bundleID, relativePath, &errPtr)
            if rc != 0 {
                if let errPtr = errPtr {
                    let errMsg = String(cString: errPtr)
                    stikpair_free_string(errPtr)
                    ContainerAccess.diag("[AirLift] ⚠️ Xóa file qua AirLift AFC cảnh báo: \(errMsg)")
                }
            } else {
                ContainerAccess.diag("[AirLift] ✅ Đã xóa tệp qua AirLift AFC: \(relativePath)")
            }
        }
    }
}
