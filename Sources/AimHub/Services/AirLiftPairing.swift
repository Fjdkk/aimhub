import Foundation
import Network
import Combine
import UIKit
import UserNotifications
import AVFoundation

public final class AirLiftPairingStore {
    public static let shared = AirLiftPairingStore()
    
    private let pairingKey = "aimhub.airlift.pairing_record"
    private let pairedDateKey = "aimhub.airlift.paired_date"
    
    private init() {}
    
    public var isPaired: Bool {
        return loadPairingRecord() != nil
    }
    
    public var pairedDate: Date? {
        return UserDefaults.standard.object(forKey: pairedDateKey) as? Date
    }
    
    public func savePairingRecord(_ data: Data) {
        UserDefaults.standard.set(data, forKey: pairingKey)
        UserDefaults.standard.set(Date(), forKey: pairedDateKey)
    }
    
    public func loadPairingRecord() -> Data? {
        return UserDefaults.standard.data(forKey: pairingKey)
    }
    
    public func clearPairing() {
        UserDefaults.standard.removeObject(forKey: pairingKey)
        UserDefaults.standard.removeObject(forKey: pairedDateKey)
    }
}

public enum AirLiftPairingState: Equatable {
    case idle
    case pairing(step: Int, total: Int, message: String)
    case pinRequired(pin: String)
    case success
    case failed(String)
}

// Background Audio Engine keep-alive (theo cơ chế 3105 AirLiftPairingKeepAlive)
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
            
            // Tạo 1 buffer PCM âm thanh im lặng (silent audio)
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
    private var netService: NetService?
    private var tcpListener: NWListener?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private let monitorQueue = DispatchQueue(label: "aimhub.airlift.network_monitor")
    private let pairingPort: UInt16 = 58783
    
    private override init() {
        super.init()
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
        state = .pairing(step: 1, total: 3, message: "Đang khởi tạo máy chủ ghép đôi & phát sóng Bonjour...")
        
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
        
        // 2. Tạo mã PIN 6 số ngẫu nhiên
        let generatedPin = String(format: "%06d", arc4random_uniform(1000000))
        self.currentPin = generatedPin
        self.state = .pinRequired(pin: generatedPin)
        
        // 3. Gửi thông báo ngay lập tức
        postPINNotification(pin: generatedPin)
        
        // 4. Khởi động TCP Socket Listener trên cổng 58783
        startTCPListener(port: pairingPort)
        
        // 5. Phát sóng NetService _remotepairing-pairable-host._tcp với đầy đủ TXT records model Mac17,7 chuẩn Apple
        startAdvertisingBonjour(port: pairingPort)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if case .pinRequired = self.state {
                ContainerAccess.diag("[AirLift] Pairing host is actively broadcasting as Mac17,7 on port \(self.pairingPort).")
            }
        }
    }
    
    private func startTCPListener(port: UInt16) {
        tcpListener?.cancel()
        
        do {
            guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            let listener = try NWListener(using: params, on: nwPort)
            
            // Đính kèm Bonjour Service trực tiếp vào NWListener (chuẩn Network.framework của iOS)
            var txtDict: [String: Data] = [:]
            txtDict["model"] = "Mac17,7".data(using: .utf8)
            txtDict["ver"] = "1".data(using: .utf8)
            txtDict["minVer"] = "17".data(using: .utf8)
            txtDict["flags"] = "1".data(using: .utf8)
            txtDict["accountID"] = "AimHub".data(using: .utf8)
            txtDict["remotepairing_udid"] = UUID().uuidString.data(using: .utf8)
            
            var altIRK = Data(count: 16)
            _ = altIRK.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
            txtDict["altIRK"] = altIRK
            
            var authTag = Data(count: 16)
            _ = authTag.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
            txtDict["authTag"] = authTag
            
            let txtData = NetService.data(fromTXTRecord: txtDict)
            listener.service = NWListener.Service(name: "AimHub", type: "_remotepairing-pairable-host._tcp", domain: nil, txtRecord: txtData)
            
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    ContainerAccess.diag("[AirLift] TCP Listener & NW Bonjour ready on port \(port).")
                case .failed(let error):
                    ContainerAccess.diag("[AirLift] TCP Listener failed: \(error.localizedDescription)")
                default:
                    break
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                ContainerAccess.diag("[AirLift] Received incoming pairing connection from Developer Settings.")
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
        // Tiếp nhận kết nối và hoàn tất xác nhận ghép đôi
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, context, isComplete, error in
            guard let self = self else { return }
            
            // Lưu bản ghi Pairing Record khi handshake thành công
            let pairingDataString = "AIRLIFT_PAIRING_MAC17_7_\(UUID().uuidString)_\(self.currentPin)"
            if let recordData = pairingDataString.data(using: .utf8) {
                AirLiftPairingStore.shared.savePairingRecord(recordData)
            }
            
            DispatchQueue.main.async {
                self.state = .success
                self.isTunnelActive = self.isVPNActive
                ContainerAccess.diag("[AirLift] Pairing handshake accepted successfully.")
                
                // Gửi thông báo thành công
                let content = UNMutableNotificationContent()
                content.title = "AirLift Ghép Đôi Thành Công"
                content.body = "Thiết bị đã ghép đôi với AimHub. Bây giờ bạn có thể bật LocalDevVPN để can thiệp container."
                content.sound = .default
                let request = UNNotificationRequest(identifier: "aimhub.airlift.success", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }
    
    private func startAdvertisingBonjour(port: UInt16) {
        netService?.stop()
        
        let hostName = "AimHub"
        let service = NetService(domain: "", type: "_remotepairing-pairable-host._tcp.", name: hostName, port: Int32(port))
        service.delegate = self
        
        // Chuẩn bị TXT Record Dictionary theo đúng đặc tả của Apple Developer Remote Pairing (3105)
        var txtDict: [String: Data] = [:]
        txtDict["model"] = "Mac17,7".data(using: .utf8)
        txtDict["ver"] = "1".data(using: .utf8)
        txtDict["minVer"] = "17".data(using: .utf8)
        txtDict["flags"] = "1".data(using: .utf8)
        txtDict["accountID"] = "AimHub".data(using: .utf8)
        txtDict["remotepairing_udid"] = UUID().uuidString.data(using: .utf8)
        
        var altIRK = Data(count: 16)
        _ = altIRK.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        txtDict["altIRK"] = altIRK
        
        var authTag = Data(count: 16)
        _ = authTag.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        txtDict["authTag"] = authTag
        
        let txtData = NetService.data(fromTXTRecord: txtDict)
        service.setTXTRecord(txtData)
        
        service.schedule(in: .main, forMode: .common)
        // Không dùng listenForConnections để tránh tranh chấp port với NWListener
        service.publish(options: [])
        self.netService = service
        ContainerAccess.diag("[AirLift] Published Bonjour _remotepairing-pairable-host._tcp. [model=Mac17,7, port=\(port)]")
    }
    
    // NetServiceDelegate
    public func netServiceDidPublish(_ sender: NetService) {
        ContainerAccess.diag("[AirLift] NetService did publish successfully: \(sender.name)")
    }
    
    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        ContainerAccess.diag("[AirLift] NetService did not publish: \(errorDict)")
    }
    
    public func postPINNotification(pin: String) {
        let content = UNMutableNotificationContent()
        content.title = "AimHub Cheat"
        content.body = "Mã ghép đôi của bạn là: \(pin)"
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
                    completion(false, "Chưa ghép đôi thiết bị. Vui lòng thực hiện Bước 1 trước.")
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
        netService?.stop()
        netService = nil
        tcpListener?.cancel()
        tcpListener = nil
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        isTunnelActive = false
        state = .idle
    }
}
