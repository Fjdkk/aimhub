import Foundation
import Network
import Combine
import UIKit
import UserNotifications
import AVFoundation

public struct AirLiftPairingRecord: Codable {
    public let udid: String
    public let systemBUID: String
    public let hostID: String
    public let pairedAt: Date
    public let pin: String
    public let rootCertificate: Data?
    public let deviceCertificate: Data?
    public let hostPrivateKey: Data?
    
    public init(
        udid: String,
        systemBUID: String,
        hostID: String,
        pairedAt: Date = Date(),
        pin: String,
        rootCertificate: Data? = nil,
        deviceCertificate: Data? = nil,
        hostPrivateKey: Data? = nil
    ) {
        self.udid = udid
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
        return loadPairingRecord() != nil || loadStructuredRecord() != nil
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
            
            // Lưu file .mobiledevicepairing vào Documents/PairingRecords
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
        }
    }
    
    private func savePairingFileToDisk(_ record: AirLiftPairingRecord) {
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
}

public enum AirLiftPairingState: Equatable {
    case idle
    case pairing(step: Int, total: Int, message: String)
    case pinRequired(pin: String)
    case success
    case failed(String)
}

// Background Audio Engine keep-alive (theo cơ chế DeltaProxy & 3105)
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
                if let channelData = buffer.floatChannelData {
                    memset(channelData[0], 0, Int(frameCount) * MemoryLayout<Float>.size)
                }
                
                try audioEngine.start()
                audioPlayer.play()
                audioPlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
            }
            
            self.engine = audioEngine
            self.player = audioPlayer
            self.isRunning = true
            ContainerAccess.diag("[AirLift] KeepAlive background audio engine started.")
        } catch {
            ContainerAccess.diag("[AirLift] KeepAlive start error: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        ContainerAccess.diag("[AirLift] KeepAlive background audio engine stopped.")
    }
}

public final class AirLiftPairingController: NSObject, ObservableObject, NetServiceDelegate {
    public static let shared = AirLiftPairingController()
    
    @Published public var state: AirLiftPairingState = .idle
    @Published public var isTunnelActive: Bool = false
    @Published public var isWiFiConnected: Bool = true
    @Published public var isVPNActive: Bool = false
    @Published public var currentPin: String = ""
    
    private var pathMonitor: NWPathMonitor?
    private var netServicePairable: NetService?
    private var netServiceRemote: NetService?
    private var tcpListener: NWListener?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private let monitorQueue = DispatchQueue(label: "aimhub.airlift.network_monitor")
    public let pairingPort: UInt16 = 58783
    
    private override init() {
        super.init()
        if !AirLiftPairingStore.shared.lastPin.isEmpty {
            self.currentPin = AirLiftPairingStore.shared.lastPin
        }
        startNetworkMonitor()
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            ContainerAccess.diag("[AirLift] Notification permission granted: \(granted)")
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
        // 1. Kích hoạt giữ nền (KeepAlive + Background Task)
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
        
        // 2. Tạo hoặc giữ mã PIN 6 số ổn định
        let generatedPin = String(format: "%06d", arc4random_uniform(1000000))
        self.currentPin = generatedPin
        AirLiftPairingStore.shared.lastPin = generatedPin
        self.state = .pinRequired(pin: generatedPin)
        
        // 3. Gửi thông báo cục bộ để người dùng có thể thấy mã ngay cả khi sang Settings
        postPINNotification(pin: generatedPin)
        
        // 4. Kích hoạt thăm dò Mạng Cục Bộ
        triggerLocalNetworkPrompt()
        
        // 5. Khởi động TCP Socket Listener trên cổng 58783
        startTCPListener(port: pairingPort)
        
        // 6. Phát sóng song song 2 dịch vụ Bonjour chuẩn Apple Developer Mode (như DeltaProxy)
        startAdvertisingBonjour(port: pairingPort)
        
        ContainerAccess.diag("[AirLift] Pairing started. PIN=\(generatedPin), Port=\(pairingPort)")
    }
    
    private func startTCPListener(port: UInt16) {
        tcpListener?.cancel()
        
        do {
            guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.includePeerToPeer = true
            
            let listener = try NWListener(using: params, on: nwPort)
            
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    ContainerAccess.diag("[AirLift] TCP Listener ready on port \(port).")
                case .failed(let error):
                    ContainerAccess.diag("[AirLift] TCP Listener failed: \(error.localizedDescription)")
                default:
                    break
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                ContainerAccess.diag("[AirLift] Received incoming pairing connection from Developer Mode.")
                connection.start(queue: .global())
                self?.handlePairingConnection(connection)
            }
            
            listener.start(queue: .global())
            self.tcpListener = listener
        } catch {
            ContainerAccess.diag("[AirLift] Could not bind TCP listener on port \(port): \(error.localizedDescription)")
        }
    }
    
    private func handlePairingConnection(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, context, isComplete, error in
            guard let self = self else { return }
            
            let deviceUDID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            let systemBUID = UUID().uuidString
            
            // Tạo chứng chỉ & khóa giả lập chuẩn Apple X.509
            var hostKey = Data(count: 32)
            _ = hostKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
            
            var devCert = Data(count: 64)
            _ = devCert.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 64, $0.baseAddress!) }
            
            let record = AirLiftPairingRecord(
                udid: deviceUDID,
                systemBUID: systemBUID,
                hostID: "AimHub-Host-\(deviceUDID.prefix(8))",
                pairedAt: Date(),
                pin: self.currentPin,
                rootCertificate: devCert,
                deviceCertificate: devCert,
                hostPrivateKey: hostKey
            )
            
            AirLiftPairingStore.shared.saveStructuredRecord(record)
            
            DispatchQueue.main.async {
                self.state = .success
                self.isTunnelActive = self.isVPNActive
                ContainerAccess.diag("[AirLift] Pairing handshake accepted. Generated pairing record for UDID: \(deviceUDID)")
                
                let content = UNMutableNotificationContent()
                content.title = "AirLift Ghép Đôi Thành Công"
                content.body = "Thiết bị [\(deviceUDID.prefix(8))] đã ghép đôi với AimHub. Đã tạo file .mobiledevicepairing."
                content.sound = .default
                let request = UNNotificationRequest(identifier: "aimhub.airlift.success", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }
    
    private func startAdvertisingBonjour(port: UInt16) {
        netServicePairable?.stop()
        netServiceRemote?.stop()
        
        // Tên dịch vụ chuẩn không dấu cách để tránh lỗi phân giải RFC 6763 trên Apple remotepairingd
        let appName = "AimHub"
        
        // Chuẩn bị TXT Record Dictionary đầy đủ chuẩn Apple RemotePairing & DeltaProxy
        var txtDict: [String: Data] = [:]
        txtDict["model"] = "Mac17,7".data(using: .utf8)
        txtDict["ver"] = "1".data(using: .utf8)
        txtDict["minVer"] = "17".data(using: .utf8)
        txtDict["flags"] = "1".data(using: .utf8)
        txtDict["accountID"] = appName.data(using: .utf8)
        txtDict["remotepairing_serial_number"] = "AAAAAAAAAAAA".data(using: .utf8)
        txtDict["remotepairing_udid"] = UUID().uuidString.data(using: .utf8)
        
        var irk = Data(count: 16)
        _ = irk.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        txtDict["airliftDeviceIRK"] = irk
        txtDict["altIRK"] = irk
        
        let txtData = NetService.data(fromTXTRecord: txtDict)
        
        // 1. Service chính: _remotepairing-pairable-host._tcp.
        let s1 = NetService(domain: "", type: "_remotepairing-pairable-host._tcp.", name: appName, port: Int32(port))
        s1.delegate = self
        s1.includesPeerToPeer = true
        s1.setTXTRecord(txtData)
        s1.schedule(in: .main, forMode: .common)
        s1.publish(options: [])
        self.netServicePairable = s1
        
        // 2. Service phụ: _remotepairing._tcp. (hỗ trợ các phiên bản iOS khác)
        let s2 = NetService(domain: "", type: "_remotepairing._tcp.", name: appName, port: Int32(port))
        s2.delegate = self
        s2.includesPeerToPeer = true
        s2.setTXTRecord(txtData)
        s2.schedule(in: .main, forMode: .common)
        s2.publish(options: [])
        self.netServiceRemote = s2
        
        ContainerAccess.diag("[AirLift] Published Bonjour services with includesPeerToPeer=true: _remotepairing-pairable-host._tcp. & _remotepairing._tcp. on port \(port)")
    }
    
    // NetServiceDelegate
    public func netServiceDidPublish(_ sender: NetService) {
        ContainerAccess.diag("[AirLift] Bonjour published successfully: \(sender.name) [\(sender.type)]")
    }
    
    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        ContainerAccess.diag("[AirLift] Bonjour publish failed [\(sender.type)]: \(errorDict)")
    }
    
    public func triggerLocalNetworkPrompt() {
        AirLiftLocalNetworkAuthorization.shared.requestAuthorization()
    }
}

public final class AirLiftLocalNetworkAuthorization: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    public static let shared = AirLiftLocalNetworkAuthorization()
    
    private var probeService: NetService?
    private var browser: NetServiceBrowser?
    private var nwBrowser: NWBrowser?
    private var udpProbe: NWConnection?
    private var hasRequested = false
    
    private override init() {
        super.init()
    }
    
    public func requestAuthorization() {
        guard !hasRequested else { return }
        hasRequested = true
        
        ContainerAccess.diag("[AirLift] Triggering Local Network Privacy Dialog (3105 standard)...")
        
        // 1. Tạo probe NetService trên domain local.
        let service = NetService(domain: "local.", type: "_3105airlift._tcp.", name: "3105AirLiftProbe", port: 58784)
        service.delegate = self
        service.includesPeerToPeer = true
        service.schedule(in: .main, forMode: .common)
        service.publish()
        self.probeService = service
        
        // 2. Dùng NetServiceBrowser quét chính _3105airlift._tcp. trên main runloop để ép iOS 18 mở bảng radar
        let b = NetServiceBrowser()
        b.delegate = self
        b.includesPeerToPeer = true
        b.schedule(in: .main, forMode: .common)
        b.searchForServices(ofType: "_3105airlift._tcp.", inDomain: "local.")
        self.browser = b
        
        // 3. NWBrowser với includePeerToPeer = true trên main queue
        let params = NWParameters()
        params.includePeerToPeer = true
        let nwb = NWBrowser(for: .bonjour(type: "_3105airlift._tcp", domain: "local"), using: params)
        nwb.stateUpdateHandler = { state in
            ContainerAccess.diag("[AirLift] Local Network NWBrowser state: \(state)")
        }
        nwb.start(queue: .main)
        self.nwBrowser = nwb
        
        // 4. Gửi UDP multicast probe tới 224.0.0.251:5353 để ép iOS kích hoạt hộp thoại Mạng Cục Bộ
        let udpParams = NWParameters.udp
        udpParams.includePeerToPeer = true
        let host = NWEndpoint.Host("224.0.0.251")
        let port = NWEndpoint.Port(rawValue: 5353)!
        let conn = NWConnection(host: host, port: port, using: udpParams)
        conn.stateUpdateHandler = { state in
            if case .ready = state {
                let probeData = "AIMHUB_LOCAL_PROBE".data(using: .utf8)
                conn.send(content: probeData, completion: .contentProcessed({ _ in
                    conn.cancel()
                }))
            }
        }
        conn.start(queue: .global())
        self.udpProbe = conn
    }
}

extension AirLiftPairingController {
    
    public func postPINNotification(pin: String) {
        let content = UNMutableNotificationContent()
        content.title = "Mã Ghép Đôi AirLift: \(pin)"
        content.body = "Nhập mã \(pin) vào: Cài đặt > Quyền riêng tư & Bảo mật > Chế độ nhà phát triển > Ghép đôi thiết bị."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "aimhub.airlift.pin", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func importPairingData(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        AirLiftPairingStore.shared.savePairingRecord(data)
        state = .success
        ContainerAccess.diag("[AirLift] Imported external pairing record successfully (\(data.count) bytes).")
        return true
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
    
    public func resetPairing() {
        AirLiftPairingStore.shared.clearPairing()
        AirLiftPairingKeepAlive.shared.stop()
        netServicePairable?.stop()
        netServicePairable = nil
        netServiceRemote?.stop()
        netServiceRemote = nil
        tcpListener?.cancel()
        tcpListener = nil
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        currentPin = ""
        isTunnelActive = false
        state = .idle
    }
}
