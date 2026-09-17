import Foundation

public enum IFixPatchSynthesizer {
    /// Toàn bộ logic mod được quản lý và xử lý trực tiếp 100% trên server.
    /// App chỉ đóng vai trò tải file chính xác từ server về và dán nguyên bản vào game container.
    public static func synthesize(baseData: Data, activeSlots: Set<String>) -> Data {
        return baseData
    }
}
