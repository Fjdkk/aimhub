import Foundation
import Darwin

public final class AirLiftTransport {
    public static let shared = AirLiftTransport()
    
    private init() {}
    
    /// Kiểm tra xem chế độ AirLift có đang sẵn sàng để đọc ghi không
    public var isAvailable: Bool {
        return AirLiftPairingStore.shared.isPaired && AirLiftPairingController.shared.isTunnelActive
    }
    
    /// Đọc nội dung tệp thông qua đường hầm AirLift khi Sandbox trực tiếp bị chặn
    public func readFile(atPath path: String) throws -> Data {
        guard isAvailable || POSIXFile.exists(path) else {
            throw POSIXFileError.io("AirLift tunnel chưa sẵn sàng hoặc không tìm thấy file: \(path)")
        }
        return try POSIXFile.read(from: path)
    }
    
    /// Ghi nội dung tệp vào container thông qua quyền AirLift
    public func writeFile(data: Data, toPath path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try POSIXFile.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try POSIXFile.write(data: data, to: path)
        ContainerAccess.diag("[AirLift] Đã dán tệp an toàn qua AirLift: \(path) (\(data.count) bytes)")
    }
    
    /// Xóa tệp qua AirLift
    public func removeFile(atPath path: String) throws {
        if POSIXFile.exists(path) {
            try POSIXFile.remove(path)
            ContainerAccess.diag("[AirLift] Đã dọn dẹp tệp qua AirLift: \(path)")
        }
    }
}
