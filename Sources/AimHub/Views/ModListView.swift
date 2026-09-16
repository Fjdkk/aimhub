import SwiftUI

struct TabItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let order: Int
}

struct ModListView: View {
    let game: Game
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var allRules: [RuleDetail] = []
    @State private var tabs: [TabItem] = []
    @State private var selectedTabID: String = "all"
    @State private var busyModID: String?
    @State private var errorText: String?
    @State private var loaded = false
    @State private var toastText: String?
    @State private var toastOK = true

    var displayedRules: [RuleDetail] {
        if selectedTabID == "all" {
            return allRules
        }
        return allRules.filter { rule in
            if let tid = rule.tabID {
                return tid == selectedTabID
            }
            if selectedTabID == "tab_aim" {
                return true
            }
            return false
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if !tabs.isEmpty {
                    tabBar
                        .padding(.bottom, 8)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L10n.t("mod.oneAtATime"))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 12)

                        if allRules.isEmpty && !loaded {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            ForEach(displayedRules) { rule in
                                modRow(rule)
                            }
                            if displayedRules.isEmpty {
                                Text(L10n.t("mod.none"))
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.muted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 20)
                            }
                        }

                        resetButton
                            .padding(.top, 16)

                        Text(L10n.t("mod.resetHint"))
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

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    let isSelected = selectedTabID == tab.id
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            selectedTabID = tab.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(tab.name)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .foregroundColor(isSelected ? .white : Theme.muted)
                        .background(
                            ZStack {
                                if isSelected {
                                    Theme.gradient()
                                        .cornerRadius(16)
                                        .shadow(color: Theme.accent.opacity(0.45), radius: 6, y: 2)
                                } else {
                                    Theme.card
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Theme.border, lineWidth: 0.8)
                                        )
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
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

    private func iconForTab(name: String, id: String) -> String {
        let low = (name + " " + id).lowercased()
        if low.contains("aim") || low.contains("ngắm") { return "crosshair" }
        if low.contains("định vị") || low.contains("locator") || low.contains("wall") || low.contains("tường") { return "eye.fill" }
        if low.contains("esp") || low.contains("box") { return "viewfinder" }
        if low.contains("skin") || low.contains("súng") || low.contains("đồ") { return "tshirt.fill" }
        return "slider.horizontal.3"
    }

    private func loadRules() async {
        defer { loaded = true }
        let allowed = appState.activeKey?.mods
        let projects = game.projects ?? []
        for project in projects {
            if let detail = try? await ServerClient.shared.fetchProject(projectID: project.id) {
                let filtered = filter(detail.rules, allowed: allowed)
                allRules = filtered

                // Xây dựng danh sách Tab động
                var extractedTabs: [TabItem] = []
                extractedTabs.append(TabItem(id: "all", name: "Tất cả", icon: "square.grid.2x2.fill", order: 0))

                if let serverTabs = detail.tabs, !serverTabs.isEmpty {
                    for st in serverTabs {
                        if st.visible != false {
                            extractedTabs.append(TabItem(
                                id: st.id,
                                name: st.name,
                                icon: iconForTab(name: st.name, id: st.id),
                                order: st.order ?? 99
                            ))
                        }
                    }
                } else {
                    var seenIDs = Set<String>()
                    for r in filtered {
                        let tid = r.tabID ?? "tab_aim"
                        let tname = r.tabName ?? "List Aim"
                        if r.tabVisible != false && !seenIDs.contains(tid) {
                            seenIDs.insert(tid)
                            extractedTabs.append(TabItem(
                                id: tid,
                                name: tname,
                                icon: iconForTab(name: tname, id: tid),
                                order: r.tabOrder ?? 99
                            ))
                        }
                    }
                }

                if extractedTabs.count <= 1 {
                    extractedTabs = [
                        TabItem(id: "all", name: "Tất cả", icon: "square.grid.2x2.fill", order: 0),
                        TabItem(id: "tab_aim", name: "List Aim", icon: "crosshair", order: 1),
                        TabItem(id: "tab_locator", name: "Định Vị + Xuyên tường", icon: "eye.fill", order: 2),
                        TabItem(id: "tab_esp_box", name: "ESP BOX", icon: "viewfinder", order: 3),
                        TabItem(id: "tab_skin", name: "Skin Mod", icon: "tshirt.fill", order: 4)
                    ]
                }

                tabs = extractedTabs.sorted(by: { $0.order < $1.order })
                if selectedTabID.isEmpty || !tabs.contains(where: { $0.id == selectedTabID }) {
                    selectedTabID = tabs.first?.id ?? "all"
                }

                if !allRules.isEmpty { return }
            }
        }
        allRules = []
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
        let isOn = appState.isModActive(ruleID: rule.ruleID)
        let busy = busyModID == rule.ruleID
        let isEnabled = rule.enabled != false
        let isInject = rule.mode == "inject"

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(rule.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isOn ? .white : (isEnabled ? Theme.text : Theme.muted))
                        .shadow(color: isOn ? Theme.accent.opacity(0.7) : .clear, radius: 8)

                    if !isEnabled {
                        Text("Bảo trì")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.red.opacity(0.15))
                            .cornerRadius(6)
                    } else if isInject {
                        Text("Xoá khi tắt")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Theme.accent.opacity(0.12))
                            .cornerRadius(4)
                    }
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
            .opacity(isEnabled ? 1.0 : 0.4)
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
                guard isEnabled else {
                    showToast("Chức năng này đang tạm bảo trì trên máy chủ!", ok: false)
                    return
                }
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
                Text(L10n.t("mod.reset"))
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

    private func currentActiveSlots(incorporating rule: RuleDetail, enabling: Bool) -> Set<String> {
        var slots = Set<String>()
        for r in allRules {
            if appState.isModActive(ruleID: r.ruleID) {
                if let slot = r.slot {
                    slots.insert(slot)
                }
            }
        }
        if let currentSlot = rule.slot {
            if enabling {
                slots.insert(currentSlot)
            } else {
                slots.remove(currentSlot)
            }
        }
        return slots
    }

    private func toggle(_ rule: RuleDetail) {
        guard let game = appState.activeGame else { return }
        busyModID = rule.ruleID
        errorText = nil

        if appState.isModActive(ruleID: rule.ruleID) {
            Task {
                do {
                    try await appState.turnOffMod(rule)
                    let dest = rule.destination ?? ""
                    if dest.contains("Assembly-CSharp-patch.bytes") {
                        let remainingSlots = currentActiveSlots(incorporating: rule, enabling: false)
                        let remainingIFix = allRules.filter {
                            ($0.destination ?? "").contains("Assembly-CSharp-patch.bytes") && appState.isModActive(ruleID: $0.ruleID)
                        }
                        if let firstRemaining = remainingIFix.first {
                            // Cập nhật lại file patch tổng hợp cho các tính năng IFix còn lại
                            let baseData = try await ServerClient.shared.downloadRuleFile(ruleID: firstRemaining.ruleID)
                            let synth = IFixPatchSynthesizer.synthesize(baseData: baseData, activeSlots: remainingSlots)
                            let configJson = "{\"testCodePatch\":true,\"resetGuest\":true}"
                            var files: [ModFile] = [
                                ModFile(name: firstRemaining.name, relativePath: dest, data: synth)
                            ]
                            if let configData = configJson.data(using: .utf8) {
                                files.append(ModFile(name: "localConfig.json", relativePath: "Documents/localConfig.json", data: configData))
                                files.append(ModFile(name: "localconfig.json", relativePath: "Documents/localconfig.json", data: configData))
                            }
                            let entry = ModEntry(id: firstRemaining.ruleID, displayName: firstRemaining.name, description: "", files: files)
                            try ModManager.shared.installMod(entry, bundleID: game.bundleID, mode: "inject")
                        }
                    }
                    busyModID = nil
                    showToast(String(format: L10n.t("mod.off"), rule.name))
                } catch {
                    busyModID = nil
                    errorText = error.localizedDescription
                }
            }
            return
        }

        Task {
            do {
                // Tự động tắt bất kỳ mod nào cùng nhóm xung đột (vd: đổi giữa Aim Legit, Aim Lock, Aim Scope, Aim Silent)
                let isAimExclusive = (rule.slot == "aim_legit" || rule.slot == "aim_lock" || rule.slot == "aim_on_scope" || rule.slot == "aim_silent")
                for other in allRules {
                    guard other.ruleID != rule.ruleID, appState.isModActive(ruleID: other.ruleID) else { continue }
                    let sameGroup = (rule.conflictGroup != nil && rule.conflictGroup == other.conflictGroup)
                    let isOtherAim = (other.slot == "aim_legit" || other.slot == "aim_lock" || other.slot == "aim_on_scope" || other.slot == "aim_silent")
                    if sameGroup || (isAimExclusive && isOtherAim) {
                        try await appState.turnOffMod(other)
                    }
                }

                let modEntry = try await buildModEntry(rule, game: game)
                try await appState.installMod(modEntry, rule: rule)
                busyModID = nil
                showToast(String(format: L10n.t("mod.on"), rule.name))
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
                showToast(L10n.t("mod.allRestored"))
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
        var finalBytes = bytes

        // Nếu là mod patch IFix -> tổng hợp tất cả các tính năng đang bật vào 1 file patch hoàn chỉnh
        if destination.contains("Assembly-CSharp-patch.bytes") {
            let activeSlots = currentActiveSlots(incorporating: rule, enabling: true)
            finalBytes = IFixPatchSynthesizer.synthesize(baseData: bytes, activeSlots: activeSlots)
        }

        var files: [ModFile] = [
            ModFile(name: rule.name, relativePath: destination, data: finalBytes)
        ]

        // Tự động nạp kèm localConfig.json
        if destination.contains("Assembly-CSharp-patch.bytes") {
            let configJson = "{\"testCodePatch\":true,\"resetGuest\":true}"
            if let configData = configJson.data(using: .utf8) {
                files.append(ModFile(name: "localConfig.json", relativePath: "Documents/localConfig.json", data: configData))
                files.append(ModFile(name: "localconfig.json", relativePath: "Documents/localconfig.json", data: configData))
            }
        }

        return ModEntry(id: rule.ruleID,
                        displayName: rule.name,
                        description: "",
                        files: files)
    }

    private func gameLogoName(_ bundleID: String) -> String {
        switch bundleID {
        case GameBundleID.freeFireMax: return "GameFFMax"
        case GameBundleID.freeFire: return "GameFF"
        default: return "Logo"
        }
    }
}