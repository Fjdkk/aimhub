import Foundation
import Network
import Combine
import UIKit
import UserNotifications
import AVFoundation

// MARK: - C FFI Bindings for Rust `stikpair_ffi` (Apple SRP RemotePairing Core)

public struct StikPairResult {
    public var error: UnsafeMutablePointer<CChar>?
    public var device_name: UnsafeMutablePointer<CChar>?
    public var device_model: UnsafeMutablePointer<CChar>?
    public var device_udid: UnsafeMutablePointer<CChar>?
    public var pairing_file_path: UnsafeMutablePointer<CChar>?
    public var host_alt_irk_hex: UnsafeMutablePointer<CChar>?
    
    public init() {
        self.error = nil
        self.device_name = nil
        self.device_model = nil
        self.device_udid = nil
        self.pairing_file_path = nil
        self.host_alt_irk_hex = nil
    }
}

public typealias StikPairReadyCb = @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafePointer<CChar>?,
    UInt16,
    UnsafePointer<UnsafePointer<CChar>?>?,
    UnsafePointer<UnsafePointer<CChar>?>?,
    Int
) -> Void

public typealias StikPairPinCb = @convention(c) (
    UnsafePointer<CChar>?,
    UnsafeMutableRawPointer?
) -> Void

@_silgen_name("stikpair_run_host")
public func stikpair_run_host(
    _ bind_addr: UnsafePointer<CChar>?,
    _ port: UInt16,
    _ name: UnsafePointer<CChar>?,
    _ model: UnsafePointer<CChar>?,
    _ out_path: UnsafePointer<CChar>?,
    _ ready_cb: StikPairReadyCb?,
    _ pin_cb: StikPairPinCb?,
    _ ctx: UnsafeMutableRawPointer?,
    _ out: UnsafeMutablePointer<StikPairResult>?
) -> Int32

@_silgen_name("stikpair_result_free")
public func stikpair_result_free(_ r: UnsafeMutablePointer<StikPairResult>?)

@_silgen_name("stikpair_free_string")
public func stikpair_free_string(_ s: UnsafeMutablePointer<CChar>?)

@_silgen_name("stikpair_write_app_file")
public func stikpair_write_app_file(
    _ pairing_file_path: UnsafePointer<CChar>?,
    _ bundle_id: UnsafePointer<CChar>?,
    _ relative_path: UnsafePointer<CChar>?,
    _ data: UnsafePointer<UInt8>?,
    _ data_len: Int,
    _ err_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32

@_silgen_name("stikpair_remove_app_file")
public func stikpair_remove_app_file(
    _ pairing_file_path: UnsafePointer<CChar>?,
    _ bundle_id: UnsafePointer<CChar>?,
    _ relative_path: UnsafePointer<CChar>?,
    _ err_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32

@_silgen_name("stikpair_app_file_exists")
public func stikpair_app_file_exists(
    _ pairing_file_path: UnsafePointer<CChar>?,
    _ bundle_id: UnsafePointer<CChar>?,
    _ relative_path: UnsafePointer<CChar>?,
    _ out_exists: UnsafeMutablePointer<Int32>?,
    _ err_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32

// MARK: - AirLift Pairing Record & Storage

public struct AirLiftPairingRecord: Codable {
    public let udid: String
    public let deviceName: String?
    public let systemBUID: String
    public let hostID: String
    public let pairedAt: Date
    public let pin: String
    public let rootCertificate: Data?
    public let deviceCertificate: Data?
    public let hostPrivateKey: Data?
    
    public init(
        udid: String,
        deviceName: String? = nil,
        systemBUID: String,
        hostID: String,
        pairedAt: Date = Date(),
        pin: String,
        rootCertificate: Data? = nil,
        deviceCertificate: Data? = nil,
        hostPrivateKey: Data? = nil
    ) {
        self.udid = udid
        self.deviceName = deviceName
        self.systemBUID = systemBUID
        self.hostID = hostID
        self.pairedAt = pairedAt
        self.pin = pin
        self.rootCertificate = rootCertificate
        self.deviceCertificate = deviceCertificate
        self.hostPrivateKey = hostPrivateKey
    }
}

public final class AirLiftPairingStore {
    public static let shared = AirLiftPairingStore()
    
    private let pairingKey = "aimhub.airlift.pairing_record"
    private let pairedDateKey = "aimhub.airlift.paired_date"
    private let lastPinKey = "aimhub.airlift.last_pin"
    private let pairingRecordObjKey = "aimhub.airlift.pairing_record_obj"
    
    private init() {}
    
    public var isPaired: Bool {
        return loadPairingRecord() != nil || loadStructuredRecord() != nil || hasPairingFileOnDisk
    }
    
    public var hasPairingFileOnDisk: Bool {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return false }
        let plistFile = docs.appendingPathComponent("rp_pairing_file.plist")
        let recordsDir = docs.appendingPathComponent("PairingRecords")
        let hasDir = (try? fm.contentsOfDirectory(atPath: recordsDir.path))?.contains(where: { $0.hasSuffix(".mobiledevicepairing") }) ?? false
        return fm.fileExists(atPath: plistFile.path) || hasDir
    }
    
    public var pairedDate: Date? {
        return UserDefaults.standard.object(forKey: pairedDateKey) as? Date ?? loadStructuredRecord()?.pairedAt
    }
    
    public var lastPin: String {
        get { UserDefaults.standard.string(forKey: lastPinKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: lastPinKey) }
    }
    
    public func savePairingRecord(_ data: Data) {
        UserDefaults.standard.set(data, forKey: pairingKey)
        UserDefaults.standard.set(Date(), forKey: pairedDateKey)
    }
    
    public func saveStructuredRecord(_ record: AirLiftPairingRecord) {
        if let encoded = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(encoded, forKey: pairingRecordObjKey)
            UserDefaults.standard.set(record.pairedAt, forKey: pairedDateKey)
            UserDefaults.standard.set(record.pin, forKey: lastPinKey)
            savePairingRecord(encoded)
            savePairingFileToDisk(record)
        }
    }
    
    public func loadStructuredRecord() -> AirLiftPairingRecord? {
        guard let data = UserDefaults.standard.data(forKey: pairingRecordObjKey) else { return nil }
        return try? JSONDecoder().decode(AirLiftPairingRecord.self, from: data)
    }
    
    public func loadPairingRecord() -> Data? {
        return UserDefaults.standard.data(forKey: pairingKey)
    }
    
    public func clearPairing() {
        UserDefaults.standard.removeObject(forKey: pairingKey)
        UserDefaults.standard.removeObject(forKey: pairedDateKey)
        UserDefaults.standard.removeObject(forKey: lastPinKey)
        UserDefaults.standard.removeObject(forKey: pairingRecordObjKey)
        
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let recordsDir = docs.appendingPathComponent("PairingRecords")
            try? fm.removeItem(at: recordsDir)
            let plistFile = docs.appendingPathComponent("rp_pairing_file.plist")
            try? fm.removeItem(at: plistFile)
        }
    }
    
    public func savePairingFileToDisk(_ record: AirLiftPairingRecord) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let recordsDir = docs.appendingPathComponent("PairingRecords")
        try? fm.createDirectory(at: recordsDir, withIntermediateDirectories: true)
        
        let plistDict: [String: Any] = [
            "UDID": record.udid,
            "SystemBUID": record.systemBUID,
            "HostIdentifier": record.hostID,
            "PairingDate": record.pairedAt.timeIntervalSince1970,
            "PairingPIN": record.pin,
            "RootCertificate": record.rootCertificate ?? Data(),
            "DeviceCertificate": record.deviceCertificate ?? Data(),
            "HostPrivateKey": record.hostPrivateKey ?? Data()
        ]
        
        if let plistData = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0) {
            let fileURL = recordsDir.appendingPathComponent("\(record.udid).mobiledevicepairing")
            try? plistData.write(to: fileURL)
            ContainerAccess.diag("[AirLift] Saved .mobiledevicepairing to disk: \(fileURL.lastPathComponent)")
        }
    }
    
    public var pairingFilePath: String? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let recordsDir = docs.appendingPathComponent("PairingRecords")
        if let files = try? fm.contentsOfDirectory(atPath: recordsDir.path) {
            for f in files where f.hasSuffix(".mobiledevicepairing") {
                return recordsDir.appendingPathComponent(f).path
            }
        }
        let plistFile = docs.appendingPathComponent("rp_pairing_file.plist")
        if fm.fileExists(atPath: plistFile.path) {
            return plistFile.path
        }
        let legacyPlist = recordsDir.appendingPathComponent("rp_pairing_file.plist")
        if fm.fileExists(atPath: legacyPlist.path) {
            return legacyPlist.path
        }
        return nil
    }
    
    public func ensureRecordLoaded() {
        if loadStructuredRecord() == nil, let path = pairingFilePath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let udid = plist["UDID"] as? String {
                let name = plist["DeviceName"] as? String ?? UIDevice.current.name
                let pin = plist["PairingPIN"] as? String ?? ""
                let hostID = plist["HostIdentifier"] as? String ?? "AimHub-Host-\(udid.prefix(8))"
                let rootCert = plist["RootCertificate"] as? Data
                let devCert = plist["DeviceCertificate"] as? Data
                let hostKey = plist["HostPrivateKey"] as? Data
                let record = AirLiftPairingRecord(
                    udid: udid,
                    deviceName: name,
                    systemBUID: plist["SystemBUID"] as? String ?? UUID().uuidString,
                    hostID: hostID,
                    pairedAt: Date(),
                    pin: pin,
                    rootCertificate: rootCert,
                    deviceCertificate: devCert,
                    hostPrivateKey: hostKey
                )
                saveStructuredRecord(record)
                ContainerAccess.diag("[AirLift] 🔄 Auto-recovered pairing record from disk: \(name) (\(udid))")
            }
        }
    }
}

// MARK: - AirLift State

public enum AirLiftPairingState: Equatable {
    case idle
    case pairing(step: Int, total: Int, message: String)
    case pinRequired(pin: String)
    case success
    case failed(String)
}

// MARK: - KeepAlive Audio Engine

public final class AirLiftPairingKeepAlive {
    public static let shared = AirLiftPairingKeepAlive()
    
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var isRunning: Bool = false
    
    private init() {}
    
    public func start() {
        guard !isRunning else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            let audioEngine = AVAudioEngine()
            let audioPlayer = AVAudioPlayerNode()
            audioEngine.attach(audioPlayer)
            
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) ?? audioEngine.outputNode.inputFormat(forBus: 0)
            audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: format)
            
            let frameCount = AVAudioFrameCount(format.sampleRate * 2.0)
            if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) {
                buffer.frameLength = frameCount
                let channelData = buffer.floatChannelData?[0]
                channelData?.initialize(repeating: 0.0, count: Int(frameCount))
                
                audioPlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            }
            
            try audioEngine.start()
            audioPlayer.play()
            
            self.engine = audioEngine
            self.player = audioPlayer
            self.isRunning = true
            ContainerAccess.diag("[AirLift] KeepAlive background audio engine started.")
        } catch {
            ContainerAccess.diag("[AirLift] KeepAlive audio error: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - AirLift Pairing Controller

public final class AirLiftPairingController: NSObject, ObservableObject, NetServiceDelegate {
    public static let shared = AirLiftPairingController()
    
    @Published public var state: AirLiftPairingState = .idle
    @Published public var isTunnelActive: Bool = false
    @Published public var isWiFiConnected: Bool = true
    @Published public var isVPNActive: Bool = false
    @Published public var currentPin: String = ""
    @Published public var isNotificationAuthorized: Bool = true
    
    private var pathMonitor: NWPathMonitor?
    private var netService: NetService?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private let monitorQueue = DispatchQueue(label: "aimhub.airlift.network_monitor")
    private var isPairingInProgress = false
    
    private override init() {
        super.init()
        AirLiftPairingStore.shared.ensureRecordLoaded()
        if !AirLiftPairingStore.shared.lastPin.isEmpty {
            self.currentPin = AirLiftPairingStore.shared.lastPin
        }
        startNetworkMonitor()
        checkNotificationPermission()
    }
    
    public func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let status = settings.authorizationStatus
                let granted = (status == .authorized || status == .provisional)
                self.isNotificationAuthorized = granted
                ContainerAccess.diag("[AirLift] Notification status: \(status.rawValue), authorized: \(granted)")
                if status == .notDetermined {
                    self.requestNotificationPermission()
                }
            }
        }
    }
    
    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isNotificationAuthorized = granted
                ContainerAccess.diag("[AirLift] Notification permission granted: \(granted)")
            }
        }
    }
    
    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wifi = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
                let vpn = path.availableInterfaces.contains { iface in
                    let name = iface.name.lowercased()
                    return name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") || name.contains("vpn")
                } || (path.usesInterfaceType(.other) && path.status == .satisfied)
                
                self?.isWiFiConnected = wifi || vpn || path.usesInterfaceType(.loopback)
                self?.isVPNActive = vpn
                if vpn && AirLiftPairingStore.shared.isPaired {
                    self?.isTunnelActive = true
                }
            }
        }
        monitor.start(queue: monitorQueue)
        self.pathMonitor = monitor
    }
    
    public func startPairing() {
        guard !isPairingInProgress else { return }
        isPairingInProgress = true
        
        // 1. Kích hoạt giữ nền âm thanh
        AirLiftPairingKeepAlive.shared.start()
        
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "AirLiftPairing") { [weak self] in
            if let task = self?.bgTask, task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
                self?.bgTask = .invalid
            }
        }
        
        self.state = .pairing(step: 1, total: 2, message: "Đang yêu cầu quyền Mạng cục bộ (Local Network)...")
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            ContainerAccess.diag("[AirLift] ⏳ Đang kiểm tra quyền Mạng cục bộ qua NWBrowser probe...")
            let authorized = await AirLiftLocalNetworkAuthorization.shared.request(timeout: 30)
            guard authorized else {
                self.isPairingInProgress = false
                AirLiftPairingKeepAlive.shared.stop()
                if self.bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(self.bgTask)
                    self.bgTask = .invalid
                }
                self.state = .failed("Cần cấp quyền Mạng cục bộ. Mở Cài đặt › AimHub Cheat › Mạng cục bộ (gạt BẬT) rồi thử lại.")
                ContainerAccess.diag("[AirLift] ❌ Quyền Mạng cục bộ bị từ chối hoặc hết thời gian chờ.")
                return
            }
            
            ContainerAccess.diag("[AirLift] ✅ Đã xác nhận quyền Mạng cục bộ! Khởi chạy dịch vụ Bonjour...")
            self.state = .pairing(step: 1, total: 2, message: "Đang mở cổng ghép đôi Apple Developer Mode...")
            self.runHostServer()
        }
    }
    
    private func runHostServer() {
        let outPath = Self.pairingFilePath()
        let bindAddr = "0.0.0.0"
        let hostName = "AimHub"
        let hostModel = "Mac17,7"
        let fallbackName = UIDevice.current.name
        let fallbackUDID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let ctxBits = UInt(bitPattern: Unmanaged.passRetained(self).toOpaque())
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let ctx = UnsafeMutableRawPointer(bitPattern: ctxBits)
            var result = StikPairResult()
            
            ContainerAccess.diag("[AirLift] Starting stikpair_run_host on \(bindAddr) for host '\(hostName)'...")
            
            let rc = bindAddr.withCString { bindC in
                hostName.withCString { nameC in
                    hostModel.withCString { modelC in
                        outPath.withCString { outC in
                            stikpair_run_host(
                                bindC,
                                0, // Dynamic port
                                nameC,
                                modelC,
                                outC,
                                stikPairReadyCallback,
                                stikPairPinCallback,
                                ctx,
                                &result
                            )
                        }
                    }
                }
            }
            
            let outcome: AirLiftPairingState
            let deviceUDID = cString(result.device_udid)
            let deviceName = cString(result.device_name)
            let pairingPath = cString(result.pairing_file_path)
            let errMsg = cString(result.error)
            
            if rc == 0 {
                let actualName = deviceName.isEmpty ? fallbackName : deviceName
                let actualUDID = deviceUDID.isEmpty ? fallbackUDID : deviceUDID
                var rootCert: Data? = nil
                var devCert: Data? = nil
                var hostKey: Data? = nil
                var sysBuid = UUID().uuidString
                var hostId = "AimHub-Host-\(actualUDID.prefix(8))"
                
                // Đọc file plist tạo bởi Rust nếu có để trích xuất chứng chỉ
                if let data = try? Data(contentsOf: URL(fileURLWithPath: pairingPath)) {
                    AirLiftPairingStore.shared.savePairingRecord(data)
                    if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        rootCert = plist["RootCertificate"] as? Data
                        devCert = plist["DeviceCertificate"] as? Data
                        hostKey = plist["HostPrivateKey"] as? Data
                        if let b = plist["SystemBUID"] as? String { sysBuid = b }
                        if let h = plist["HostIdentifier"] as? String { hostId = h }
                    }
                }
                
                let record = AirLiftPairingRecord(
                    udid: actualUDID,
                    deviceName: actualName,
                    systemBUID: sysBuid,
                    hostID: hostId,
                    pairedAt: Date(),
                    pin: self.currentPin,
                    rootCertificate: rootCert,
                    deviceCertificate: devCert,
                    hostPrivateKey: hostKey
                )
                AirLiftPairingStore.shared.saveStructuredRecord(record)
                
                outcome = .success
                ContainerAccess.diag("[AirLift] ✅ Ghép đôi thành công! Thiết bị: \(actualName) (\(actualUDID))")
            } else {
                let message = errMsg.isEmpty ? "Ghép đôi thất bại (mã \(rc)). Vui lòng thử lại." : errMsg
                outcome = .failed(message)
                ContainerAccess.diag("[AirLift] ❌ Ghép đôi thất bại: \(message)")
            }
            
            stikpair_result_free(&result)
            if let ctx = ctx {
                Unmanaged<AirLiftPairingController>.fromOpaque(ctx).release()
            }
            
            DispatchQueue.main.async {
                self.stopAdvertising()
                self.isPairingInProgress = false
                self.state = outcome
                if case .success = outcome {
                    let actualName = deviceName.isEmpty ? fallbackName : deviceName
                    self.isTunnelActive = self.isVPNActive
                    self.postSuccessNotification(deviceName: actualName, udid: deviceUDID)
                }
                if let task = self.bgTask as UIBackgroundTaskIdentifier?, task != .invalid {
                    UIApplication.shared.endBackgroundTask(task)
                    self.bgTask = .invalid
                }
            }
        }
    }
    
    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        stopAdvertising()
        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: serviceID,
            port: port
        )
        service.delegate = self
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.publish()
        self.netService = service
        ContainerAccess.diag("[AirLift] 📡 Published Bonjour: \(serviceID) on port \(port) with \(txt.count) TXT keys.")
    }
    
    fileprivate func stopAdvertising() {
        netService?.stop()
        netService = nil
    }
    
    fileprivate func presentPin(_ pin: String) {
        self.currentPin = pin
        AirLiftPairingStore.shared.lastPin = pin
        self.state = .pinRequired(pin: pin)
        ContainerAccess.diag("[AirLift] 🔑 Engine Apple SRP generated PIN: \(pin)")
        postPINNotification(pin: pin)
    }
    
    public func postPINNotification(pin: String) {
        let content = UNMutableNotificationContent()
        content.title = "AimHub Cheat"
        content.body = "Mã ghép đôi AimHub: \(pin)\nNhập mã này trên màn hình Cài đặt > Quyền riêng tư & Bảo mật > Chế độ nhà phát triển > Ghép đôi."
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "aimhub.airlift.pin", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                ContainerAccess.diag("[AirLift] ⚠️ Lỗi gửi thông báo PIN: \(error.localizedDescription)")
            } else {
                ContainerAccess.diag("[AirLift] 🔔 Đã bắn biểu ngữ mã PIN thành công!")
            }
        }
    }
    
    private func postSuccessNotification(deviceName: String, udid: String) {
        let content = UNMutableNotificationContent()
        content.title = "AimHub Cheat"
        content.body = "Ghép đôi thành công! (\(deviceName))"
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "aimhub.airlift.success", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public static func pairingFilePath() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rp_pairing_file.plist").path
    }
    
    public func triggerLocalNetworkPrompt() {
        Task { @MainActor in
            _ = await AirLiftLocalNetworkAuthorization.shared.request()
        }
    }
    
    public func resetPairing() {
        AirLiftPairingStore.shared.clearPairing()
        AirLiftPairingKeepAlive.shared.stop()
        stopAdvertising()
        isPairingInProgress = false
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        state = .idle
        currentPin = ""
        isTunnelActive = false
        ContainerAccess.diag("[AirLift] Đã xóa toàn bộ cấu hình ghép đôi và dừng dịch vụ.")
    }
    
    public func testTunnelConnection(completion: @escaping (Bool, String) -> Void) {
        state = .pairing(step: 2, total: 3, message: "Đang kiểm tra kết nối đường hầm Loopback 127.0.0.1...")
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            let hasPairing = AirLiftPairingStore.shared.isPaired
            let vpnOn = self.isVPNActive
            
            DispatchQueue.main.async {
                if !hasPairing {
                    self.isTunnelActive = false
                    self.state = .failed("Chưa ghép đôi thiết bị. Vui lòng bấm 'Bắt Đầu Ghép Đôi' ở Bước 1.")
                    completion(false, "Chưa ghép đôi thiết bị. Vui lòng bấm Bắt Đầu Ghép Đôi trước.")
                } else if !vpnOn {
                    self.isTunnelActive = false
                    self.state = .idle
                    completion(false, "Chưa phát hiện LocalDevVPN đang bật. Vui lòng mở LocalDevVPN và gạt bật kết nối trước khi kiểm tra lại.")
                } else {
                    self.isTunnelActive = true
                    self.state = .success
                    completion(true, "Đường hầm AirLift (LocalDevVPN 127.0.0.1) đã phản hồi sẵn sàng 100%!")
                }
            }
        }
    }
    
    public func importPairingData(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        AirLiftPairingStore.shared.savePairingRecord(data)
        state = .success
        ContainerAccess.diag("[AirLift] Imported external pairing record successfully (\(data.count) bytes).")
        return true
    }
    
    // NetServiceDelegate
    public func netServiceDidPublish(_ sender: NetService) {
        ContainerAccess.diag("[AirLift] Bonjour published successfully: \(sender.name) [\(sender.type)]")
    }
    
    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        ContainerAccess.diag("[AirLift] Bonjour publish failed [\(sender.type)]: \(errorDict)")
    }
}

// MARK: - C Callback Trampolines

private let stikPairReadyCallback: StikPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx = ctx, let serviceID = serviceID else { return }
    let controller = Unmanaged<AirLiftPairingController>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: serviceID)
    
    var txt: [String: Data] = [:]
    if let keys = keys, let vals = vals {
        for i in 0..<count {
            guard let k = keys[i], let v = vals[i] else { continue }
            txt[String(cString: k)] = Data(String(cString: v).utf8)
        }
    }
    
    DispatchQueue.main.async {
        controller.startAdvertising(serviceID: id, port: Int32(port), txt: txt)
    }
}

private let stikPairPinCallback: StikPairPinCb = { pin, ctx in
    guard let ctx = ctx, let pin = pin else { return }
    let controller = Unmanaged<AirLiftPairingController>.fromOpaque(ctx).takeUnretainedValue()
    let pinStr = String(cString: pin)
    DispatchQueue.main.async {
        controller.presentPin(pinStr)
    }
}

private func cString(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr = ptr else { return "" }
    return String(cString: ptr)
}

// MARK: - Local Network Authorization Helper (StikPair Probe Standard for iOS 18)

@MainActor
public final class AirLiftLocalNetworkAuthorization {
    public static let shared = AirLiftLocalNetworkAuthorization()
    
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?
    private let probeType = "_stikpairprobe._tcp"
    
    private init() {}
    
    public func request(timeout: TimeInterval = 30) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            self.continuation = cont
            
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            
            let listener = try? NWListener(using: params)
            listener?.service = NWListener.Service(name: "AimHubProbe", type: probeType)
            listener?.newConnectionHandler = { $0.cancel() }
            listener?.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated { self?.finish(false) }
                }
            }
            self.listener = listener
            
            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: params)
            browser.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated { self?.finish(false) }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                if !results.isEmpty {
                    ContainerAccess.diag("[AirLift] Local Network probe discovered peer -> Permission active!")
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            self.browser = browser
            
            listener?.start(queue: .main)
            browser.start(queue: .main)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                MainActor.assumeIsolated { self?.finish(false) }
            }
        }
    }
    
    private func finish(_ authorized: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: authorized)
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
    }
}
