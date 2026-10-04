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
    
    private var actionButtonsCard: some View {
        VStack(spacing: 12) {
            // Hiển thị mã PIN nếu đang trong quá trình ghép đôi
            if !controller.currentPin.isEmpty && !AirLiftPairingStore.shared.isPaired {
                VStack(spacing: 6) {
                    Text("MÃ GHÉP ĐÔI NHÀ PHÁT TRIỂN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.muted)
                    
                    Text(controller.currentPin)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundColor(Theme.accent)
                        .tracking(6)
                        .padding(.vertical, 4)
                    
                    Text("Nhập mã này vào Cài đặt > Nhà phát triển > Ghép đôi")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
            }
            
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
}
