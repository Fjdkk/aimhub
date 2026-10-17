import SwiftUI

struct TabItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let order: Int
    let note: String?

    init(id: String, name: String, icon: String, order: Int, note: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.order = order
        self.note = note
    }
}

struct ModListView: View {
    let game: Game
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var allRules: [RuleDetail] = []
    @State private var previewSkinRule: RuleDetail? = nil
    @State private var tabs: [TabItem] = []
    @State private var selectedTab: TabItem? = nil
    @State private var busyModID: String?
    @State private var errorText: String?
    @State private var loaded = false
    @State private var toastText: String?
    @State private var toastOK = true
    @State private var showPairingPrompt = false
    @State private var showPreCleanRequiredAlert = false
    @State private var pendingRuleToEnable: RuleDetail? = nil

    var displayedRules: [RuleDetail] {
        guard let tab = selectedTab else { return [] }
        return allRules.filter { rule in
            if let tid = rule.tabID {
                return tid == tab.id
            }
            if tab.id == "tab_aim" {
                let nameLow = rule.name.lowercased()
                let slotLow = (rule.slot ?? "").lowercased()
                return nameLow.contains("aim") || slotLow.contains("aim") || slotLow.contains("magic_bullet")
            }
            return false
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if selectedTab == nil {
                    categoryListView
                } else {
                    modListView
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
        .alert("Yêu Cầu Ghép Đôi", isPresented: $showPairingPrompt) {
            Button("Đến Ghép Đôi") {
                appState.selectedTab = .settings
                dismiss()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Không thể truy cập thư mục game do giới hạn sandbox. Bạn có muốn chuyển sang tab Cài Đặt > Ghép Đôi để kích hoạt không?")
        }
        .alert("Chưa Dọn Dẹp An Toàn!", isPresented: $showPreCleanRequiredAlert) {
            Button("Dọn dẹp ngay") {
                guard let rule = pendingRuleToEnable, let game = appState.activeGame else { return }
                busyModID = rule.ruleID
                showToast("Đang dọn dẹp hệ thống...", ok: true)
                FFAntiBanService.shared.runAntiBanV2PreClean(bundleID: game.bundleID) { success in
                    if success {
                        showToast("Đã dọn dẹp an toàn! Đang bật mod...", ok: true)
                        executeEnableMod(rule, game: game)
                    } else {
                        showToast("Dọn dẹp thất bại, hãy thử lại!", ok: false)
                        busyModID = nil
                    }
                }
            }
            Button("Hủy", role: .cancel) {
                pendingRuleToEnable = nil
            }
        } message: {
            Text("Bạn chưa kích hoạt dọn dẹp AntiBan V2. Vui lòng dọn dẹp trước khi Bật Mod.")
        }
    }

    private var categoryListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("DANH MỤC CHỨC NĂNG")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                Text("Chọn một danh mục bên dưới để xem và kích hoạt các mod")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 16)

                if allRules.isEmpty && !loaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    let availableTabs = tabs.filter {
                        $0.id != "all"
                    }
                    ForEach(availableTabs) { tab in
                        categoryRow(tab)
                    }

                    resetButton
                        .padding(.top, 20)

                    Text(L10n.t("mod.resetHint"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted.opacity(0.75))
                        .padding(.horizontal, 4)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func categoryRow(_ tab: TabItem) -> some View {
        let count = allRules.filter {
            if let tid = $0.tabID { return tid == tab.id }
            return tab.id == "tab_aim"
        }.count

        let activeCount = allRules.filter {
            let matchesTab: Bool
            if let tid = $0.tabID { matchesTab = (tid == tab.id) }
            else { matchesTab = (tab.id == "tab_aim") }
            return matchesTab && appState.isModActive(ruleID: $0.ruleID)
        }.count

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 14) {
                Image(gameLogoName(game.bundleID))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tab.name.precomposedStringWithCanonicalMapping)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.text)

                        if let note = sanitizeTabNote(tab.note) {
                            Text("• \(note)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.green.opacity(0.14))
                                .cornerRadius(6)
                        }

                        if activeCount > 0 {
                            Text("\(activeCount) đang bật")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.green.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }

                    Text("\(count) tính năng có sẵn")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }
            .card(padding: 14)
            .padding(.bottom, 10)
        }
        .buttonStyle(.plain)
    }

    private var modListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let note = sanitizeTabNote(selectedTab?.note) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.green)
                        Text(note)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.green.opacity(0.14))
                    .cornerRadius(8)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)
                }

                Text(L10n.t("mod.oneAtATime"))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)

                if displayedRules.isEmpty {
                    Text(L10n.t("mod.none"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                } else {
                    ForEach(displayedRules) { rule in
                        modRow(rule)
                    }
                }

                launchGameActionButton
                    .padding(.top, 16)

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

    private func sanitizeTabNote(_ note: String?) -> String? {
        guard let n = note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
        let low = n.lowercased()
        if low.contains("vào game") || low.contains("vao game") || low.contains("game trước") || low.contains("game truoc") || low.contains("trước nhé") || low.contains("truoc nhe") {
            return nil
        }
        return n
    }

    private func iconForTab(name: String, id: String) -> String {
        let low = (name + " " + id).lowercased()
        if low.contains("menu") || low.contains("aimhub") { return "bolt.shield.fill" }
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
                                order: st.order ?? 99,
                                note: sanitizeTabNote(st.note)
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
                                order: r.tabOrder ?? 99,
                                note: sanitizeTabNote(r.tabNote)
                            ))
                        }
                    }
                }

                if extractedTabs.count <= 1 {
                    extractedTabs = [
                        TabItem(id: "all", name: "Tất cả", icon: "square.grid.2x2.fill", order: 0),
                        TabItem(id: "tab_aim", name: "List Aim", icon: "crosshair", order: 1),
                        TabItem(id: "tab_locator", name: "Định Vị + Xuyên tường", icon: "eye.fill", order: 2),
                        TabItem(id: "tab_esp_aim", name: "ESP + AIMBOT", icon: "viewfinder", order: 3),
                        TabItem(id: "tab_skin", name: "Skin Mod", icon: "tshirt.fill", order: 4),
                        TabItem(id: "tab_menu_aimhub", name: "Menu AimHub", icon: "bolt.shield.fill", order: 5)
                    ]
                }

                tabs = extractedTabs.sorted(by: { $0.order < $1.order })
                if !allRules.isEmpty { return }
            }
        }
        allRules = []
    }

    private func filter(_ list: [RuleDetail], allowed: [String]?) -> [RuleDetail] {
        let cleanList = list
        guard let allowed = allowed, !allowed.isEmpty else { return cleanList }
        let currentBundle = game.bundleID.lowercased()
        let hasBundlePrefixed = allowed.contains(where: { $0.contains(":") })

        return cleanList.filter { rule in
            if let slot = rule.slot, !slot.isEmpty {
                let slotKey = slot.lowercased()
                // 1. Khớp chính xác quyền theo game: "bundleID:slot"
                if allowed.contains(where: { $0.lowercased() == "\(currentBundle):\(slotKey)" }) {
                    return true
                }
                // 2. Khớp nếu cấp toàn quyền cho riêng game này: "bundleID:*" hoặc "bundleID"
                if allowed.contains(where: { $0.lowercased() == "\(currentBundle):*" || $0.lowercased() == currentBundle }) {
                    return true
                }
                // 3. Tương thích ngược: nếu key cấp dạng slot không gắn tiền tố game
                if !hasBundlePrefixed && allowed.contains(where: { $0.lowercased() == slotKey }) {
                    return true
                }
                return false
            }
            return true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if selectedTab != nil {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        selectedTab = nil
                    }
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                    if selectedTab != nil {
                        Text("Danh mục")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .foregroundColor(Theme.muted)
            }
            .padding(.trailing, 2)

            Image(gameLogoName(game.bundleID))
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text((selectedTab?.name ?? "AimHub Mods").precomposedStringWithCanonicalMapping)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accent2],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                Text(game.name)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
            }

            Spacer()
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
                    Text(rule.name.precomposedStringWithCanonicalMapping)
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

            // Nút xem ảnh kế bên chỗ bật tắt các gói skin
            if rule.fullImageURL != nil || rule.tabID == "tab_skin" || selectedTab?.id == "tab_skin" {
                Button {
                    previewSkinRule = rule
                } label: {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(8)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }

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
            Task { @MainActor in
                defer { busyModID = nil }
                do {
                    try await appState.turnOffMod(rule)
                    let dest = rule.destination ?? ""
                    if dest.contains("Assembly-CSharp-patch.bytes") {
                        let remainingSlots = currentActiveSlots(incorporating: rule, enabling: false)
                        let remainingIFix = allRules.filter {
                            ($0.destination ?? "").contains("Assembly-CSharp-patch.bytes") && appState.isModActive(ruleID: $0.ruleID)
                        }
                        if let firstRemaining = remainingIFix.first {
                            let baseData = try await ServerClient.shared.downloadRuleFile(ruleID: firstRemaining.ruleID, activeSlots: Array(remainingSlots))
                            let configJson = "{\"testCodePatch\":true,\"resetGuest\":true}"
                            var files: [ModFile] = [
                                ModFile(name: firstRemaining.name, relativePath: dest, data: baseData)
                            ]
                            if let configData = configJson.data(using: .utf8) {
                                files.append(ModFile(name: "localConfig.json", relativePath: "Documents/localConfig.json", data: configData))
                            }
                            let entry = ModEntry(id: firstRemaining.ruleID, displayName: firstRemaining.name, description: "", files: files)
                            try ModManager.shared.installMod(entry, bundleID: game.bundleID, mode: "inject")
                        }
                    }
                    showToast(String(format: L10n.t("mod.off"), rule.name))
                } catch {
                    errorText = error.localizedDescription
                    showToast(error.localizedDescription, ok: false)
                    if !AirLiftPairingStore.shared.isPaired {
                        showPairingPrompt = true
                    }
                }
            }
            return
        }

        // BẢO VỆ ANTIBAN: Bắt buộc dọn dẹp trước khi bật mod
        if !FFAntiBanService.shared.isAntiBanActive {
            busyModID = nil
            pendingRuleToEnable = rule
            showPreCleanRequiredAlert = true
            return
        }

        executeEnableMod(rule, game: game)
    }

    private func executeEnableMod(_ rule: RuleDetail, game: Game) {
        busyModID = rule.ruleID
        Task { @MainActor in
            defer { busyModID = nil }
            do {
                // Tự động tắt bất kỳ mod nào cùng nhóm xung đột
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
                showToast(String(format: L10n.t("mod.on"), rule.name))
            } catch {
                errorText = error.localizedDescription
                showToast(error.localizedDescription, ok: false)
                if !AirLiftPairingStore.shared.isPaired {
                    showPairingPrompt = true
                }
            }
        }
    }

    private func resetAll() {
        guard busyModID == nil else { return }
        busyModID = "reset"
        Task { @MainActor in
            defer { busyModID = nil }
            do {
                try await appState.restoreAll()
                if let game = appState.activeGame {
                    ModManager.shared.neutralizePatch(bundleID: game.bundleID)
                }
                showToast(L10n.t("mod.allRestored"))
            } catch {
                errorText = error.localizedDescription
                showToast(error.localizedDescription, ok: false)
                if !AirLiftPairingStore.shared.isPaired {
                    showPairingPrompt = true
                }
            }
        }
    }

    private func buildModEntry(_ rule: RuleDetail, game: Game) async throws -> ModEntry {
        let destination = rule.destination ?? "Documents/\(rule.ruleID).bin"
        var activeSlots: Set<String>? = nil
        if destination.contains("Assembly-CSharp-patch.bytes") {
            activeSlots = currentActiveSlots(incorporating: rule, enabling: true)
        }

        let bytes: Data
        do {
            bytes = try await ServerClient.shared.downloadRuleFile(ruleID: rule.ruleID, activeSlots: activeSlots != nil ? Array(activeSlots!) : nil)
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
        var files: [ModFile] = [
            ModFile(name: rule.name, relativePath: destination, data: bytes)
        ]

        // Tự động nạp kèm localConfig.json
        if destination.contains("Assembly-CSharp-patch.bytes") {
            let configJson = "{\"testCodePatch\":true,\"resetGuest\":true}"
            if let configData = configJson.data(using: .utf8) {
                files.append(ModFile(name: "localConfig.json", relativePath: "Documents/localConfig.json", data: configData))
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

    private var launchGameActionButton: some View {
        Button {
            launchGame()
        } label: {
            HStack(spacing: 8) {
                Image(gameLogoName(game.bundleID))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))

                Text("VÀO GAME NGAY")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(colors: [Theme.green, Theme.accent], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
            .shadow(color: Theme.green.opacity(0.35), radius: 6, y: 2)
        }
    }

    private func launchGame() {
        appState.selectGame(game)
        let directContainer = try? ContainerAccess.shared.gameContainerPath(bundleID: game.bundleID)
        FFAntiBanService.shared.purgeTelemetryAndIntegrity(bundleID: game.bundleID, directContainer: directContainer)
        FFAntiBanService.shared.normalizeMetadata(bundleID: game.bundleID, directContainer: directContainer)
        appState.openGame()
        showToast("Đang mở \(game.name) với Anti-Ban V2...", ok: true)
    }
}

// MARK: - Skin Preview Sheet Component
struct SkinPreviewSheet: View {
    let rule: RuleDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header card with Name and badges
                        VStack(spacing: 8) {
                            Text(rule.name.precomposedStringWithCanonicalMapping)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 8) {
                                if let slot = rule.slot {
                                    Text(slot.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Theme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.accent.opacity(0.15))
                                        .cornerRadius(6)
                                }
                                if let group = rule.conflictGroup, !group.isEmpty {
                                    Text(group.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.top, 10)

                        // Image display
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.11, green: 0.13, blue: 0.18))
                                .frame(maxWidth: .infinity)
                                .frame(height: 320)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border, lineWidth: 1)
                                )

                            if let url = rule.fullImageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        VStack(spacing: 10) {
                                            ProgressView()
                                                .tint(Theme.accent)
                                            Text("Đang tải ảnh xem trước...")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.muted)
                                        }
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 300)
                                            .cornerRadius(12)
                                            .padding(10)
                                    case .failure:
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.exclamationmark")
                                                .font(.system(size: 36))
                                                .foregroundColor(.red.opacity(0.8))
                                            Text("Không thể tải ảnh xem trước")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Theme.muted)
                                            if let img = rule.imageURL {
                                                Text(img)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(Theme.muted.opacity(0.6))
                                                    .lineLimit(2)
                                                    .padding(.horizontal, 20)
                                            }
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.muted.opacity(0.5))
                                    Text("Chưa có ảnh xem trước từ server")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.muted)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Close button
                        Button {
                            dismiss()
                        } label: {
                            Text("Đóng")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.gradient())
                                .cornerRadius(12)
                                .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 3)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Xem Trước Gói Skin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.muted)
                    }
                }
            }
        }
    }
}
