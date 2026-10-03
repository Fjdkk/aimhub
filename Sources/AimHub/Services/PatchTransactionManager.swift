import Foundation

/// Cấu trúc biên lai giao dịch Patch (Receipt)
public struct PatchReceipt: Codable {
    public let id: String
    public let bundleID: String
    public let timestamp: Date
    public let modifiedFiles: [String]
    public let backupFiles: [String: String] // Relative path -> Backup Relative Path
    public let injectedFiles: [String]
    public var isCommitted: Bool
}

/// Quản lý giao dịch Patch an toàn (Atomic Transaction) và tự động khôi phục (Auto-Recovery)
/// Tương tự kiến trúc AirLiftPatchTransaction trong 3105.
public final class PatchTransactionManager {
    public static let shared = PatchTransactionManager()
    
    private let receiptKeyPrefix = "aimhub.patch.receipt."
    private let pendingReceiptKey = "aimhub.patch.pending_receipt"
    
    private init() {}
    
    /// Bắt đầu một phiên giao dịch Patch mới
    public func beginTransaction(bundleID: String) -> PatchReceipt {
        let receipt = PatchReceipt(
            id: UUID().uuidString,
            bundleID: bundleID,
            timestamp: Date(),
            modifiedFiles: [],
            backupFiles: [:],
            injectedFiles: [],
            isCommitted: false
        )
        savePendingReceipt(receipt)
        return receipt
    }
    
    /// Xác nhận giao dịch thành công (Commit)
    public func commitTransaction(_ receipt: PatchReceipt) {
        var committed = receipt
        committed.isCommitted = true
        
        let key = receiptKeyPrefix + receipt.bundleID
        if let data = try? JSONEncoder().encode(committed) {
            UserDefaults.standard.set(data, forKey: key)
        }
        
        // Xóa trạng thái pending
        UserDefaults.standard.removeObject(forKey: pendingReceiptKey)
        ContainerAccess.diag("[PatchTransaction] Đã commit giao dịch thành công: \(receipt.id)")
    }
    
    /// Khôi phục giao dịch nếu app bị tắt đột ngột lúc đang chép file
    public func recoverPendingTransactionsIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: pendingReceiptKey),
              let pending = try? JSONDecoder().decode(PatchReceipt.self, from: data),
              !pending.isCommitted else {
            return
        }
        
        ContainerAccess.diag("[PatchTransaction] Phát hiện giao dịch chưa hoàn tất (\(pending.id)). Đang tự động khôi phục file gốc...")
        
        do {
            for (relPath, _) in pending.backupFiles {
                try ModManager.shared.restoreFile(relativePath: relPath, bundleID: pending.bundleID)
            }
            for injPath in pending.injectedFiles {
                try ModManager.shared.restoreFile(relativePath: injPath, bundleID: pending.bundleID, mode: "inject")
            }
            UserDefaults.standard.removeObject(forKey: pendingReceiptKey)
            ContainerAccess.diag("[PatchTransaction] Tự động khôi phục hoàn tất 100%.")
        } catch {
            ContainerAccess.diag("[PatchTransaction] Lỗi tự động khôi phục: \(error.localizedDescription)")
        }
    }
    
    private func savePendingReceipt(_ receipt: PatchReceipt) {
        if let data = try? JSONEncoder().encode(receipt) {
            UserDefaults.standard.set(data, forKey: pendingReceiptKey)
        }
    }
    
    /// Dọn dẹp toàn bộ file staging và file tạm (Clean Staging & Cache)
    public func cleanStagingAndTempFiles(containerRoot: String? = nil) {
        let tempDir = NSTemporaryDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tempDir) {
            for file in files where file.hasPrefix("aimhub_") || file.hasSuffix(".tmp") || file.hasSuffix(".staging") {
                let fullPath = (tempDir as NSString).appendingPathComponent(file)
                try? POSIXFile.remove(fullPath)
            }
        }
        
        // Nếu có containerRoot, quét dọn file probe thử nghiệm
        if let root = containerRoot {
            let probePath = (root as NSString).appendingPathComponent("Documents/.aimhub_probe.tmp")
            if POSIXFile.exists(probePath) {
                try? POSIXFile.remove(probePath)
            }
        }
        ContainerAccess.diag("[PatchTransaction] Đã dọn dẹp sạch sẽ staging và file rác.")
    }
}
