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
                        systemStatusCard
                        
                        step1PairingCard
                        
                        step2TestConnectionCard
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
    
    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("airlift.status"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.muted)
                Spacer()
            }
            
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
            
            // 3. Dòng ghi chú nếu chưa bật VPN
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 2)
                Text(L10n.t("airlift.vpnHint"))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Theme.bg)
            .cornerRadius(8)
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
    
    private var step1PairingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("airlift.step1"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)
                Spacer()
                if AirLiftPairingStore.shared.isPaired {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(L10n.t("airlift.step1Desc"))
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("airlift.guide"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text(L10n.t("airlift.guideContent"))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg)
            .cornerRadius(8)
            
            if case .pinRequired(let pin) = controller.state {
                VStack(spacing: 6) {
                    Text(L10n.t("airlift.pinTitle"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.muted)
                    Text(pin)
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .foregroundColor(Theme.accent)
                    Text(L10n.t("airlift.pinSub"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Theme.bg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                )
            }
            
            Button {
                controller.startPairing()
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text(AirLiftPairingStore.shared.isPaired ? L10n.t("airlift.rePair") : L10n.t("airlift.startPairing"))
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
    
    private var step2TestConnectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("airlift.step2"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)
                Spacer()
                if controller.isTunnelActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(L10n.t("airlift.step2Desc"))
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
                    Text(L10n.t("airlift.testTunnel"))
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
}
