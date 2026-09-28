import Foundation

/// Dữ liệu nhị phân chuẩn của Neutral IFix Seed (322 bytes) trích xuất từ Sophia IPA.
/// File này hoàn toàn rỗng, không chứa mã gian lận, dùng để thay thế tẩy trắng sau khi game đã nạp hack vào RAM.
public enum NeutralSeed {
    public static let base64Payload = "y6K0DbIZo2ZkSUZpeC5JTEZpeEludGVyZmFjZUJyaWRnZSwgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABjSUZpeC5XcmFwcGVyc01hbmFnZXJJbXBsLCBBc3NlbWJseS1DU2hhcnAsIFZlcnNpb249MC44Ni4wLjUxOCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsSywgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAA=="

    public static var data: Data {
        Data(base64Encoded: base64Payload) ?? Data()
    }
}
