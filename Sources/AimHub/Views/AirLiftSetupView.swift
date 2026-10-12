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
                    VStack(spacing: 16) {
                        if !controller.isNotificationAuthorized {
                            notificationWarningCard
                        }
                        
                        systemStatusCard
                        
                        actionButtonsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle(L10n.t("airlift.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.t("airlift.close")) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(L10n.t("airlift.notice")),
                    message: Text(alertMessage ?? ""),
                    dismissButton: .default(Text(L10n.t("airlift.close")))
                )
            }
        }
    }
    
    private var notificationWarningCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.slash.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Chưa bật quyền Thông báo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
                Text("Bật thông báo trong Cài đặt để nhận mã PIN ghép đôi tức thì khi ứng dụng chạy ngầm.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
            }
            
            Spacer()
            
            Button("Mở Cài đặt") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange)
            .cornerRadius(8)
        }
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
    
    private var systemStatusCard: some View {
        VStack(spacing: 12) {
            // 1. Trạng thái ghép đôi
            HStack(spacing: 8) {
                Circle()
                    .fill(AirLiftPairingStore.shared.isPaired ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text("\(L10n.t("airlift.pairingStatus")):")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
                Spacer()
                Text(AirLiftPairingStore.shared.isPaired ? L10n.t("airlift.paired") : L10n.t("airlift.notPaired"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AirLiftPairingStore.shared.isPaired ? .green : .orange)
            }
            
            // Tên thiết bị
            if AirLiftPairingStore.shared.isPaired {
                Divider()
                    .background(Theme.border)
                
                let record = AirLiftPairingStore.shared.loadStructuredRecord()
                let displayDeviceName = record?.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (record?.deviceName ?? UIDevice.current.name) : UIDevice.current.name
                
                HStack(spacing: 8) {
                    Text("Thiết bị:")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                    Spacer()
                    Text(displayDeviceName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
            }
            
            Divider()
                .background(Theme.border)
            
            // 2. Trạng thái VPN
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.isVPNActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text("\(L10n.t("airlift.vpnStatus")):")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
                Spacer()
                Text(controller.isVPNActive ? L10n.t("airlift.vpnActive") : L10n.t("airlift.vpnInactive"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(controller.isVPNActive ? .green : .orange)
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
    
    private var actionButtonsCard: some View {
        VStack(spacing: 12) {
            // Live Pairing Status Card
            switch controller.state {
            case .pairing(let step, let total, let message):
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Đang ghép đôi (Bước \(step)/\(total))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.accent)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.muted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.12))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
            case .pinRequired(let pin):
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundColor(Theme.accent)
                    Text("Mã PIN ghép đôi: \(pin)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.12))
                .cornerRadius(12)
            case .success:
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ghép đôi thành công!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            case .failed(let reason):
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Thất bại: \(reason)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            case .idle:
                EmptyView()
            }

            Button {
                controller.startPairing()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    alertMessage = "Đã mở cổng Ghép Đôi\nVui lòng ghép đôi với thiết bị của bạn với AimHub Cheat"
                    showAlert = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text(AirLiftPairingStore.shared.isPaired ? L10n.t("airlift.rePair") : L10n.t("airlift.startPairing"))
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.gradient())
                .cornerRadius(10)
            }
            
            Button {
                controller.testTunnelConnection { ok, msg in
                    alertMessage = msg
                    showAlert = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                    Text(L10n.t("airlift.testTunnel"))
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .cornerRadius(10)
            }
            
            if AirLiftPairingStore.shared.isPaired {
                Button {
                    controller.resetPairing()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                        Text(L10n.t("airlift.unpair"))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
