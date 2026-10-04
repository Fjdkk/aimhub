import SwiftUI
import UIKit

public struct AirLiftSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = AirLiftPairingController.shared
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false
    @State private var isPinCopied: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        systemStatusCard
                        
                        if !controller.currentPin.isEmpty {
                            pinDisplayCard
                        }
                        
                        actionButtonsCard
                        
                        guideCard
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
            .onAppear {
                AirLiftLocalNetworkAuthorization.shared.requestAuthorization()
            }
        }
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
    
    private var pinDisplayCard: some View {
        VStack(spacing: 8) {
            Text("MÃ GHÉP ĐÔI NHÀ PHÁT TRIỂN")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.muted)
            
            Text(controller.currentPin)
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .foregroundColor(Theme.accent)
                .tracking(6)
                .padding(.vertical, 4)
            
            Button {
                UIPasteboard.general.string = controller.currentPin
                isPinCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isPinCopied = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isPinCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(isPinCopied ? "Đã Sao Chép Mã PIN!" : "Sao Chép Mã PIN")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isPinCopied ? .green : Theme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            
            Text("Mã PIN này được lưu cố định cho phiên làm việc. Hãy mở Cài đặt để nhập mã.")
                .font(.system(size: 11))
                .foregroundColor(Theme.muted.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.4), lineWidth: 1.5))
    }
    
    private var actionButtonsCard: some View {
        VStack(spacing: 12) {
            Button {
                controller.triggerLocalNetworkPrompt()
                controller.startPairing()
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
    
    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Theme.accent)
                Text("HƯỚNG DẪN GHÉP ĐÔI NHÀ PHÁT TRIỂN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                guideRow(step: "1", text: "Bấm 'Bắt Đầu Ghép Đôi' ở trên. Mã PIN 6 số sẽ xuất hiện và giữ nguyên.")
                guideRow(step: "2", text: "Nếu có popup xin quyền 'Mạng cục bộ', bấm 'Cho phép'.")
                guideRow(step: "3", text: "Vào Cài đặt > Quyền riêng tư & Bảo mật > Chế độ nhà phát triển > Ghép đôi thiết bị.")
                guideRow(step: "4", text: "Chọn 'AimHub Cheat' trong danh sách và nhập mã PIN 6 số.")
                guideRow(step: "5", text: "Quay lại AimHub, mở LocalDevVPN rồi bấm 'Kiểm Tra Đường Hầm'.")
            }
            
            Divider()
                .background(Theme.border)
                .padding(.vertical, 2)
            
            Text("Lưu ý: Nếu không thấy AimHub trong danh sách Ghép đôi, hãy vào Cài đặt > Quyền riêng tư & Bảo mật > Mạng cục bộ > Kiểm tra gạt BẬT cho AimHub.")
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.card.opacity(0.7))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border.opacity(0.6), lineWidth: 1))
    }
    
    private func guideRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(step)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Theme.accent)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
        }
    }
}
