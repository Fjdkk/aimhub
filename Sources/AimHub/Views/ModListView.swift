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
    @State private var selectedTab: TabItem? = nil
    @State private var busyModID: String?
    @State private var errorText: String?
    @State private var loaded = false
    @State private var toastText: String?
    @State private var toastOK = true

    // Menu AimHub State (Server-Driven Dynamic UI)
    @State private var menuSchema: MenuSchema = MenuSchema.defaultSchema
    @State private var dynamicBools: [String: Bool] = [:]
    @State private var dynamicDoubles: [String: Double] = [:]
    @State private var dynamicStrings: [String: String] = [:]
    @AppStorage("aimhub.menu.is_injected") private var isMenuInjected: Bool = false
    @State private var isInjectingMenu: Bool = false

    private var isAimHubMenuSelected: Bool {
        guard let tab = selectedTab else { return false }
        let low = tab.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tab.id == "tab_menu_aimhub" || low == "menu aimhub"
    }

    var displayedRules: [RuleDetail] {
        guard let tab = selectedTab else { return [] }
        return allRules.filter { rule in
            if let tid = rule.tabID {
                return tid == tab.id
            }
            if tab.id == "tab_aim" {
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

                if selectedTab == nil {
                    categoryListView
                } else if isAimHubMenuSelected {
                    aimHubMenuView
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
                    let availableTabs = tabs.filter { $0.id != "all" }
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

    private var aimHubMenuView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(menuSchema.sections) { section in
                    Text(section.title.precomposedStringWithCanonicalMapping)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 4)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    VStack(spacing: 8) {
                        ForEach(section.items) { item in
                            renderDynamicMenuItem(item)
                        }
                    }
                }

                // Section Action Button: Injector / Uninjector Toggle
                let actionBtn = menuSchema.actionButton
                let injectLabel = actionBtn?.injectText ?? "Injector"
                let uninjectLabel = actionBtn?.uninjectText ?? "Uninjector"
                let injectingLabel = actionBtn?.injectingText ?? "Đang Inject..."
                let uninjectingLabel = actionBtn?.uninjectingText ?? "Đang gỡ bỏ..."

                Button {
                    if isMenuInjected {
                        uninjectAimHubMenu()
                    } else {
                        injectAimHubMenu()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isInjectingMenu {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: isMenuInjected ? "eject.fill" : "bolt.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(isInjectingMenu
                             ? (isMenuInjected ? uninjectingLabel : injectingLabel)
                             : (isMenuInjected ? uninjectLabel : injectLabel))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isMenuInjected
                        ? AnyShapeStyle(LinearGradient(colors: [Color.red.opacity(0.85), Color(red: 0.7, green: 0.1, blue: 0.2)], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Theme.gradient())
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: isMenuInjected ? Color.red.opacity(0.4) : Theme.accent.opacity(0.4), radius: 10, y: 4)
                }
                .disabled(isInjectingMenu)
                .padding(.top, 26)
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func renderDynamicMenuItem(_ item: MenuItem) -> some View {
        switch item.type {
        case "toggle":
            let defVal = (item.defaultValue == "true")
            menuToggleRow(title: item.title, isOn: bindingForBool(key: item.key, defaultValue: defVal))

        case "slider":
            let minVal = item.min ?? 0
            let maxVal = item.max ?? 100
            let stepVal = item.step ?? 1
            let defVal = Double(item.defaultValue ?? "") ?? minVal
            let binding = bindingForDouble(key: item.key, defaultValue: defVal)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(binding.wrappedValue > minVal ? .white : Theme.text)
                    Spacer()
                    Text("\(Int(binding.wrappedValue))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                Slider(value: binding, in: minVal...maxVal, step: stepVal)
                    .tint(Theme.accent)
            }
            .card(padding: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 1)
            )

        case "segmented":
            let options = item.options ?? ["HEAD", "NECK", "BODY"]
            let defVal = item.defaultValue ?? options.first ?? "HEAD"
            let binding = bindingForString(key: item.key, defaultValue: defVal)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 2)

                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { opt in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                binding.wrappedValue = opt
                            }
                        } label: {
                            Text(opt)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(binding.wrappedValue == opt ? .white : Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    binding.wrappedValue == opt ? AnyShapeStyle(Theme.gradient()) : AnyShapeStyle(Theme.card2)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(binding.wrappedValue == opt ? Theme.accent.opacity(0.6) : Theme.border, lineWidth: 1)
                                )
                                .shadow(color: binding.wrappedValue == opt ? Theme.accent.opacity(0.3) : .clear, radius: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .card(padding: 14)

        default:
            EmptyView()
        }
    }

    private func menuToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isOn.wrappedValue ? .white : Theme.text)
                .shadow(color: isOn.wrappedValue ? Theme.accent.opacity(0.7) : .clear, radius: 8)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn.wrappedValue ? AnyShapeStyle(Theme.gradient()) : AnyShapeStyle(Color(red: 0.165, green: 0.2, blue: 0.271)))
                    .frame(width: 50, height: 28)
                    .shadow(color: isOn.wrappedValue ? Theme.accent.opacity(0.6) : .clear, radius: 8)
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .offset(x: isOn.wrappedValue ? 11 : -11)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isOn.wrappedValue.toggle()
                }
            }
        }
        .card(padding: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOn.wrappedValue ? Theme.accent.opacity(0.55) : Theme.border,
                        lineWidth: isOn.wrappedValue ? 1.5 : 1)
        )
    }

    private func initDynamicState(schema: MenuSchema) {
        for sec in schema.sections {
            for item in sec.items {
                let uKey = "aimhub.dynamic." + item.key
                if item.type == "toggle" {
                    if UserDefaults.standard.object(forKey: uKey) != nil {
                        dynamicBools[item.key] = UserDefaults.standard.bool(forKey: uKey)
                    } else {
                        dynamicBools[item.key] = (item.defaultValue == "true")
                    }
                } else if item.type == "slider" {
                    if UserDefaults.standard.object(forKey: uKey) != nil {
                        dynamicDoubles[item.key] = UserDefaults.standard.double(forKey: uKey)
                    } else {
                        dynamicDoubles[item.key] = Double(item.defaultValue ?? "") ?? (item.min ?? 0)
                    }
                } else if item.type == "segmented" {
                    if let str = UserDefaults.standard.string(forKey: uKey) {
                        dynamicStrings[item.key] = str
                    } else {
                        dynamicStrings[item.key] = item.defaultValue ?? item.options?.first ?? "HEAD"
                    }
                }
            }
        }
    }

    private func bindingForBool(key: String, defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: { dynamicBools[key] ?? defaultValue },
            set: { newVal in
                dynamicBools[key] = newVal
                UserDefaults.standard.set(newVal, forKey: "aimhub.dynamic." + key)
                syncLiveConfig()
            }
        )
    }

    private func bindingForDouble(key: String, defaultValue: Double) -> Binding<Double> {
        Binding(
            get: { dynamicDoubles[key] ?? defaultValue },
            set: { newVal in
                dynamicDoubles[key] = newVal
                UserDefaults.standard.set(newVal, forKey: "aimhub.dynamic." + key)
                syncLiveConfig()
            }
        )
    }

    private func bindingForString(key: String, defaultValue: String) -> Binding<String> {
        Binding(
            get: { dynamicStrings[key] ?? defaultValue },
            set: { newVal in
                dynamicStrings[key] = newVal
                UserDefaults.standard.set(newVal, forKey: "aimhub.dynamic." + key)
                syncLiveConfig()
            }
        )
    }

    /// Đồng bộ thời gian thực vào localConfig.json để game nhận ngay lập tức khi đang chạy
    private func syncLiveConfig() {
        guard isMenuInjected else { return }
        var config: [String: Any] = [
            "testCodePatch": true,
            "resetGuest": true
        ]
        var espBitmask: Int32 = 0
        if dynamicBools["esp_box"] == true { espBitmask |= 1 }
        if dynamicBools["esp_line"] == true { espBitmask |= 2 }
        if dynamicBools["esp_health"] == true { espBitmask |= 512 }
        if dynamicBools["esp_distance"] == true { espBitmask |= 32768 }
        if dynamicBools["esp_name"] == true { espBitmask |= 65536 }
        if dynamicBools["esp_skeleton"] == true { espBitmask |= 131072 }

        let targetStr = (dynamicStrings["aim_target"] ?? "HEAD").uppercased()
        let targetBone: Int32 = (targetStr == "NECK") ? 1 : ((targetStr == "BODY") ? 2 : 0)

        config["hub_st"] = espBitmask
        config["hub_aim"] = (dynamicBools["aim_bot"] == true) ? 1 : 0
        config["hub_sil"] = (dynamicBools["aim_silent"] == true) ? 1 : 0
        config["hub_tab"] = targetBone
        config["hub_fov"] = dynamicDoubles["aim_fov"] ?? 65.0
        config["hub_fov_circle"] = (dynamicBools["aim_fov_circle"] ?? true) ? 1 : 0
        config["hub_run_speed"] = (dynamicBools["speed_run"] == true) ? 1 : 0
        config["hub_crouch_speed"] = (dynamicBools["speed_crouch"] == true) ? 1 : 0
        config["hub_sky_speed"] = (dynamicBools["speed_sky"] == true) ? 1 : 0
        config["hub_heal_fast"] = (dynamicBools["heal_fast"] == true) ? 1 : 0

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            if let path = try? ModManager.shared.absolute("Documents/localConfig.json") {
                try? POSIXFile.write(data: data, to: path)
            }
            if let path2 = try? ModManager.shared.absolute("Documents/localconfig.json") {
                try? POSIXFile.write(data: data, to: path2)
            }
        }
    }

    private func injectAimHubMenu() {
        guard !isInjectingMenu else { return }
        isInjectingMenu = true

        Task {
            do {
                // 1. Thu thập dữ liệu theo schema động
                var config: [String: Any] = [
                    "testCodePatch": true,
                    "resetGuest": true
                ]
                var bitmaskMap: [String: Int] = [:]

                for section in menuSchema.sections {
                    for item in section.items {
                        if item.type == "toggle" {
                            let defVal = (item.defaultValue == "true")
                            let isOn = dynamicBools[item.key] ?? defVal
                            if let bit = item.bitmask {
                                if isOn {
                                    bitmaskMap[item.configKey, default: 0] |= bit
                                }
                            } else {
                                config[item.configKey] = isOn ? 1 : 0
                            }
                        } else if item.type == "slider" {
                            let defVal = Double(item.defaultValue ?? "") ?? (item.min ?? 65)
                            let val = dynamicDoubles[item.key] ?? defVal
                            config[item.configKey] = Int(val)
                        } else if item.type == "segmented" {
                            let defVal = item.defaultValue ?? item.options?.first ?? "HEAD"
                            let val = dynamicStrings[item.key] ?? defVal
                            config[item.configKey] = val
                        }
                    }
                }
                for (k, v) in bitmaskMap {
                    config[k] = v
                }

                let configData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])

                // Tính toán chính xác các giá trị từ các nút toggle / slider / segmented trong app
                var espBitmask: Int32 = 0
                if dynamicBools["esp_box"] == true { espBitmask |= 1 }
                if dynamicBools["esp_line"] == true { espBitmask |= 2 }
                if dynamicBools["esp_health"] == true { espBitmask |= 512 }
                if dynamicBools["esp_distance"] == true { espBitmask |= 32768 }
                if dynamicBools["esp_name"] == true { espBitmask |= 65536 }
                if dynamicBools["esp_skeleton"] == true { espBitmask |= 131072 }

                let targetStr = (dynamicStrings["aim_target"] ?? "HEAD").uppercased()
                let targetBone: Int32
                switch targetStr {
                case "NECK": targetBone = 1
                case "BODY": targetBone = 2
                default: targetBone = 0
                }

                let silentAim: Int32 = (dynamicBools["aim_silent"] == true) ? 1 : 0
                let isAimOn: Bool = (dynamicBools["aim_bot"] == true)
                let fovSliderVal: Float = Float(dynamicDoubles["aim_fov"] ?? 65.0)
                let fovCircle: Int32 = (dynamicBools["aim_fov_circle"] ?? true) ? 1 : 0

                let queryItems: [URLQueryItem] = [
                    URLQueryItem(name: "esp", value: String(espBitmask)),
                    URLQueryItem(name: "target", value: String(targetBone)),
                    URLQueryItem(name: "silent", value: String(silentAim)),
                    URLQueryItem(name: "fov", value: String(fovSliderVal)),
                    URLQueryItem(name: "aim_on", value: isAimOn ? "true" : "false"),
                    URLQueryItem(name: "fov_circle", value: String(fovCircle))
                ]

                // 3. Lấy file patch (Server tự động vá bytecode theo queryItems bảo mật)
                let patchRule = allRules.first(where: {
                    $0.tabID == "tab_menu_aimhub" || $0.ruleID.contains("aimhub") || $0.slot == "menu_aimhub"
                }) ?? allRules.first(where: {
                    ($0.destination ?? "").contains("Assembly-CSharp-patch.bytes") && ($0.size ?? 0) > 20000
                })

                let patchBytes: Data
                if let rule = patchRule {
                    patchBytes = try await ServerClient.shared.downloadRuleFile(ruleID: rule.ruleID, queryItems: queryItems)
                } else {
                    let fallbackID = game.bundleID.contains("max") ? "rule_menu_aimhub_vip_max" : "rule_menu_aimhub_vip"
                    patchBytes = try await ServerClient.shared.downloadRuleFile(ruleID: fallbackID, queryItems: queryItems)
                }

                let finalPatchBytes = patchBytes

                // 4. Đóng gói files để inject
                let files: [ModFile] = [
                    ModFile(name: "Assembly-CSharp-patch.bytes",
                            relativePath: "Documents/Assembly-CSharp-patch.bytes",
                            data: finalPatchBytes),
                    ModFile(name: "localConfig.json",
                            relativePath: "Documents/localConfig.json",
                            data: configData),
                    ModFile(name: "localconfig.json",
                            relativePath: "Documents/localconfig.json",
                            data: configData)
                ]

                let entry = ModEntry(
                    id: "aimhub_menu_vip",
                    displayName: "Menu AimHub",
                    description: "Full AimHub Features",
                    files: files
                )

                try ModManager.shared.installMod(entry, bundleID: game.bundleID, mode: "inject")
                ModManager.shared.scheduleTimedWipe(relativePath: "Documents/Assembly-CSharp-patch.bytes", delaySeconds: 7.5)

                await MainActor.run {
                    isMenuInjected = true
                    isInjectingMenu = false
                    let toastMsg = menuSchema.actionButton?.successInjectToast ?? "Đã nạp Injector thành công!"
                    showToast(toastMsg, ok: true)
                }
            } catch {
                await MainActor.run {
                    isInjectingMenu = false
                    showToast("Lỗi nạp: \(error.localizedDescription)", ok: false)
                }
            }
        }
    }

    private func uninjectAimHubMenu() {
        guard !isInjectingMenu else { return }
        isInjectingMenu = true

        Task {
            do {
                try ModManager.shared.restoreFile(relativePath: "Documents/Assembly-CSharp-patch.bytes", bundleID: game.bundleID, mode: "inject")
                try? ModManager.shared.restoreFile(relativePath: "Documents/localConfig.json", bundleID: game.bundleID, mode: "inject")
                try? ModManager.shared.restoreFile(relativePath: "Documents/localconfig.json", bundleID: game.bundleID, mode: "inject")

                await MainActor.run {
                    isMenuInjected = false
                    isInjectingMenu = false
                    let toastMsg = menuSchema.actionButton?.successUninjectToast ?? "Đã gỡ bỏ Injector thành công!"
                    showToast(toastMsg, ok: true)
                }
            } catch {
                await MainActor.run {
                    isInjectingMenu = false
                    showToast("Lỗi gỡ: \(error.localizedDescription)", ok: false)
                }
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

                // Cập nhật Server-Driven UI Schema cho Menu AimHub
                if let serverSchema = detail.menuSchema {
                    menuSchema = serverSchema
                } else {
                    menuSchema = await ServerClient.shared.fetchMenuSchema()
                }
                initDynamicState(schema: menuSchema)

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

            if selectedTab == nil {
                Text(game.bundleID.contains("max") ? "MAX" : "STANDARD")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.12))
                    .cornerRadius(12)
            }
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
                            let baseData = try await ServerClient.shared.downloadRuleFile(ruleID: firstRemaining.ruleID, activeSlots: Array(remainingSlots))
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
                isMenuInjected = false
                busyModID = nil
                showToast(L10n.t("mod.allRestored"))
            } catch {
                busyModID = nil
                errorText = error.localizedDescription
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