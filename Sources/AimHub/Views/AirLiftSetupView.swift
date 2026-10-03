import SwiftUI
import UIKit

public struct AirLiftSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = AirLiftPairingController.shared
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        
                        wifiNoticeCard
                        
                        step1PairingCard
                        
                        step2VPNCard
                        
                        step3TunnelTestCard
                        
                        infoNoteCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Ghép Đôi AirLift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Thông Báo"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("Đóng")))
            }
        }
    }
    
    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("TRẠNG THÁI AIRLIFT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.muted)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(AirLiftPairingStore.shared.isPaired ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(AirLiftPairingStore.shared.isPaired ? "Đã ghép đôi & Sẵn sàng" : "Chưa ghép đôi thiết bị")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
    
    private var wifiNoticeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: controller.isWiFiConnected ? "wifi" : "wifi.slash")
                .font(.system(size: 18))
                .foregroundColor(controller.isWiFiConnected ? .green : .yellow)
            
            Text(controller.isWiFiConnected ? "Đã kết nối mạng Wi-Fi / Mạng nội bộ hợp lệ." : "Vui lòng bật Wi-Fi để dịch vụ AirLift hoạt động ổn định nhất.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
            Spacer()
        }
        .padding(12)
        .background(Theme.card.opacity(0.6))
        .cornerRadius(12)
    }
    
    private var step1PairingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BƯỚC 1: GHÉP ĐÔI THIẾT BỊ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)
                Spacer()
                if AirLiftPairingStore.shared.isPaired {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text("Phát tín hiệu ghép đôi để nhận chứng chỉ Pairing Record từ hệ thống iOS.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
            
            if case .pinRequired(let pin) = controller.state {
                VStack(spacing: 6) {
                    Text("MÃ XÁC NHẬN GHÉP ĐÔI:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.muted)
                    Text(pin)
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(Theme.accent)
                    Text("Nhập mã này nếu hệ thống iPhone yêu cầu xác nhận.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Theme.bg)
                .cornerRadius(10)
            }
            
            Button {
                controller.startPairing()
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text(AirLiftPairingStore.shared.isPaired ? "Ghép Đôi Lại" : "Bắt Đầu Ghép Đôi")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.gradient())
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
    
    private var step2VPNCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BƯỚC 2: MỞ LOCALDEVVPN")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)
                Spacer()
            }
            
            Text("Cài đặt và bật ứng dụng LocalDevVPN từ App Store để tạo cầu nối mạng nội bộ 127.0.0.1.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
            
            Button {
                if let url = URL(string: "https://apps.apple.com/app/localdevvpn/id6448769337") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Tải LocalDevVPN (App Store)")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
    
    private var step3TunnelTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BƯỚC 3: KIỂM TRA ĐƯỜNG HẦM")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)
                Spacer()
            }
            
            Text("Sau khi đã ghép đôi và bật VPN, hãy kiểm tra kết nối để kích hoạt chế độ AirLift.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
            
            Button {
                controller.testTunnelConnection { ok, msg in
                    alertMessage = msg
                    showAlert = true
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.shield")
                    Text("Kiểm Tra Kết Nối AirLift")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
    
    private var infoNoteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LƯU Ý:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.muted)
            Text("• AirLift chỉ chạy hoàn toàn cục bộ trên iPhone (Loopback 127.0.0.1).\n• Không làm chậm mạng, không qua máy chủ trung gian và không tiêu tốn dung lượng 4G/Wi-Fi.")
                .font(.system(size: 12))
                .foregroundColor(Theme.muted)
        }
        .padding(12)
    }
}
