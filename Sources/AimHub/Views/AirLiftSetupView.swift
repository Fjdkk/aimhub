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
            Button {
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
                    controller.unpair()
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
