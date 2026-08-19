import SwiftUI

struct ModListView: View {
    let game: Game
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var rules: [RuleDetail] = []
    @State private var busyModID: String?
    @State private var errorText: String?
    @State private var loaded = false
    @State private var toastText: String?
    @State private var toastOK = true

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Chỉ được bật 1 mod. Bật mod khác thì mod cũ tự tắt.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 12)

                        if rules.isEmpty && !loaded {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            ForEach(rules) { rule in
                                modRow(rule)
                            }
                            if rules.isEmpty {
                                Text("Chưa có mod nào cho game này.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.muted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 20)
                            }
                        }

                        resetButton
                            .padding(.top, 16)

                        Text("Khi bật mod, file gốc của game được tự sao lưu trước khi ghi. Bấm RESET để khôi phục file gốc và tắt hết mod.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.muted.opacity(0.75))
                            .padding(.horizontal, 4)
                            .padding(.top, 12)

                        if let err = errorText {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.red)
                                .padding(.horizontal, 4)
                                .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            await loadRules()
        }
        .overlay(alignment: .top) {
            if let toastText = toastText {
                toast(text: toastText, ok: toastOK)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func toast(text: String, ok: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark" : "exclamationmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ok ? Theme.green : Theme.red)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .stroke((ok ? Theme.green : Theme.red).opacity(0.6), lineWidth: 1.5)
                )
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.text)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ok ? Theme.green.opacity(0.45) : Theme.red.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
    }

    private func showToast(_ message: String, ok: Bool = true) {
        withAnimation { toastText = message; toastOK = ok }
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastText == message {
                withAnimation { toastText = nil }
            }
        }
    }

    private func loadRules() async {
        defer { loaded = true }
        let allowed = appState.activeKey?.mods
        let projects = game.projects ?? []
        for project in projects {
            if let detail = try? await ServerClient.shared.fetchProject(projectID: project.id) {
                rules = filter(detail.rules, allowed: allowed)
                if !rules.isEmpty { return }
            }
        }
        rules = []
    }

    private func filter(_ list: [RuleDetail], allowed: [String]?) -> [RuleDetail] {
        guard let allowed = allowed, !allowed.isEmpty else { return list }
        return list.filter { rule in
            if let slot = rule.slot, !slot.isEmpty {
                return allowed.contains(slot)
            }
            return true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Theme.muted)
            }
            .padding(.trailing, 4)

            Image(gameLogoName(game.bundleID))
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text("AimHub Mods")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accent2],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                Text(game.bundleID)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
            }

            Spacer()

            Text(game.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.accent.opacity(0.12))
                .cornerRadius(20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func modRow(_ rule: RuleDetail) -> some View {
        let isOn = appState.activeModID == rule.ruleID
        let busy = busyModID == rule.ruleID

        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isOn ? .white : Theme.text)
                    .shadow(color: isOn ? Theme.accent.opacity(0.7) : .clear, radius: 8)
                if let size = rule.size, size > 0 {
                    Text("\(size) bytes")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                }
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? AnyShapeStyle(Theme.gradient()) : AnyShapeStyle(Color(red: 0.165, green: 0.2, blue: 0.271)))
                    .frame(width: 50, height: 28)
                    .shadow(color: isOn ? Theme.accent.opacity(0.6) : .clear, radius: 8)
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .offset(x: isOn ? 11 : -11)
            }
            .overlay {
                if busy {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Theme.text)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard busyModID == nil else { return }
                toggle(rule)
            }
        }
        .card(padding: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOn ? Theme.accent.opacity(0.55) : Theme.border,
                        lineWidth: isOn ? 1.5 : 1)
        )
        .padding(.bottom, 10)
    }

    private var resetButton: some View {
        Button {
            resetAll()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("RESET MẶC ĐỊNH")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(Theme.text)
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private func toggle(_ rule: RuleDetail) {
        guard let game = appState.activeGame else { return }
        busyModID = rule.ruleID
        errorText = nil
if appState.activeModID == rule.ruleID {
            Task {
                do {
                    try await appState.restoreAll()
                    busyModID = nil
                    showToast("Đã tắt \(rule.name) và khôi phục file gốc")
                } catch {
                    busyModID = nil
                    errorText = error.localizedDescription
                }
            }
            return
        }

        Task {
            do {
                let modEntry = try await buildModEntry(rule, game: game)
                try await appState.installMod(modEntry)
                busyModID = nil
                showToast("Đã bật \(rule.name) ✓")
                appState.openGame()
            } catch {
                busyModID = nil
                errorText = error.localizedDescription
            }
        }
    }
    private func resetAll() {
        guard busyModID == nil else { return }
        busyModID = "reset"
        Task {
            do {
                try await appState.restoreAll()
                busyModID = nil
                showToast("Đã khôi phục toàn bộ file gốc")
            } catch {
                busyModID = nil
                errorText = error.localizedDescription
            }
        }
    }

    private func buildModEntry(_ rule: RuleDetail, game: Game) async throws -> ModEntry {
        let bytes: Data
        do {
            bytes = try await ServerClient.shared.downloadRuleFile(ruleID: rule.ruleID)
        } catch {
            if let bundled = Bundle.main.url(forResource: rule.ruleID,
                                             withExtension: nil,
                                             subdirectory: "Mods"),
               let data = try? Data(contentsOf: bundled) {
                bytes = data
            } else {
                throw error
            }
        }
        let destination = rule.destination ?? "Documents/\(rule.ruleID).bin"
        let file = ModFile(name: rule.name,
                           relativePath: destination,
                           data: bytes)
        return ModEntry(id: rule.ruleID,
                        displayName: rule.name,
                        description: "",
                        files: [file])
    }

    private func gameLogoName(_ bundleID: String) -> String {
        switch bundleID {
        case GameBundleID.freeFireMax: return "GameFFMax"
        case GameBundleID.freeFire: return "GameFF"
        default: return "Logo"
        }
    }
}