import Combine
import CoreGraphics
import Foundation
import Security

actor DisplayManager: ObservableObject {
    static let shared = DisplayManager()
    
    private var activeDisplays: Set<CGDirectDisplayID> = []
    private var reconfigurationCallback: CGDisplayReconfigurationCallBack?
    private let displaySubject = PassthroughSubject<DisplayEvent, Never>()
    private var validSerialNumbers: Set<String> = []
    
    private var securityLogger = OSLog(subsystem: "com.yourapp.display", category: "Security")
    private var auditLog: [DisplaySecurityEvent] = []
    private let auditQueue = DispatchQueue(label: "com.yourapp.display.audit", qos: .utility)
    
    private var displayConfigCallback: CGDisplayReconfigurationCallBack?
    private var displays: [CGDirectDisplayID: DisplayInfo] = [:]
    private let displayQueue = DispatchQueue(label: "com.yourapp.display", qos: .userInteractive)
    
    @Published var recoveryStatus: RecoveryState = .normal
    
    private var displayStates: [CGDirectDisplayID: DisplayState] = [:]
    private let stateQueue = DispatchQueue(label: "DisplayStateQueue", qos: .userInteractive)
    
    nonisolated var displayEvents: AnyPublisher<DisplayEvent, Never> {
        displaySubject.eraseToAnyPublisher()
    }
    
    private init() {
        configureSerialNumberValidation()
        setupDisplayCallback()
        enumerateDisplays()
    }
    
    func startMonitoring() async {
        await registerReconfigurationCallback()
        await refreshDisplays()
    }
    
    func stopMonitoring() async {
        await unregisterReconfigurationCallback()
        activeDisplays.removeAll()
    }
    
    private func registerReconfigurationCallback() {
        reconfigurationCallback = { (displayID, flags, userInfo) in
            Task {
                await DisplayManager.shared.handleDisplayChange(
                    displayID: displayID,
                    flags: flags
                )
            }
        }
        
        CGDisplayRegisterReconfigurationCallback(
            reconfigurationCallback,
            nil
        )
    }
    
    private func unregisterReconfigurationCallback() {
        guard let callback = reconfigurationCallback else { return }
        CGDisplayRemoveReconfigurationCallback(callback, nil)
        reconfigurationCallback = nil
    }
    
    func handleDisplayChange(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        let isValid = validateDisplay(displayID)
        let isMainDisplay = CGDisplayIsMain(displayID) != 0
        
        Task {
            do {
                if flags.contains(.addFlag) {
                    guard isValid else {
                        throw DisplayError.serialValidationFailed
                    }
                    
                    activeDisplays.insert(displayID)
                    displaySubject.send(.displayAdded(displayID: displayID, isMain: isMainDisplay))
                    logSecurityEvent(displayID: displayID, action: "display_added", context: [:])
                } else if flags.contains(.removeFlag) {
                    activeDisplays.remove(displayID)
                    displaySubject.send(.displayRemoved(displayID: displayID))
                    logSecurityEvent(displayID: displayID, action: "display_removed", context: [:])
                }
            } catch {
                displaySubject.send(.configurationError(error: error))
                logSecurityEvent(displayID: displayID, action: "error", context: ["error": "\(error)"])
            }
        }
        
        Task {
            await SecurityAuditLogger.shared.log(event: SecurityAuditEvent(
                timestamp: Date(),
                type: .displayReconfigured,
                user: NSUserName(),
                displayID: displayID,
                parameters: ["action": "reconfigured"]
            ))
        }
    }
    
    private func refreshDisplays() async {
        var displayCount: UInt32 = 0
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(16))
        
        guard CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount) == .success else {
            return
        }
        
        activeDisplays = Set(onlineDisplays.prefix(Int(displayCount)))
            .filter { validateDisplay($0) }
    }
    
    private func configureSerialNumberValidation() {
        // Implement serial number validation logic from project requirements
        validSerialNumbers = retrieveValidDisplaySerialNumbers()
    }
    
    private func validateDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        guard let serialNumber = getDisplaySerialNumber(displayID) else {
            logSecurityEvent(displayID: displayID, action: "serial_missing", context: [:])
            return false
        }
        
        let isValid = validSerialNumbers.contains(serialNumber)
        if !isValid {
            logSecurityEvent(displayID: displayID, action: "invalid_serial", context: ["serial": serialNumber])
        }
        return isValid
    }
    
    private func getDisplaySerialNumber(_ displayID: CGDirectDisplayID) -> String? {
        guard let info = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() else {
            return nil
        }
        
        return (info[kDisplayProductID] as? NSNumber)?.stringValue
    }
    
    private func retrieveValidDisplaySerialNumbers() -> Set<String> {
        guard let data = Keychain.load(key: "validDisplaySerials"),
              let serials = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return ["default"]
        }
        return serials
    }
    
    private func logSecurityEvent(displayID: CGDirectDisplayID, action: String, context: [String: String]) {
        let event = DisplaySecurityEvent(
            displayID: displayID,
            action: action,
            context: context
        )
        
        auditQueue.async {
            self.auditLog.append(event)
            if let data = try? JSONEncoder().encode(event) {
                UserDefaults.standard.set(data, forKey: "displayAudit-\(displayID)")
            }
            
            OSLog.info("Display security: %{public}@",
                       log: self.securityLogger,
                       type: .default,
                       "\(action) - \(context)")
        }
    }
    
    func updateValidSerials(_ serials: Set<String>) throws {
        let data = try JSONEncoder().encode(serials)
        Keychain.save(key: "validDisplaySerials", data: data)
        validSerialNumbers = serials
    }
    
    private func setupDisplayCallback() {
        displayConfigCallback = { (displayID, flags, userInfo) in
            guard let userInfo = userInfo else { return }
            let manager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
            
            manager.displayQueue.async {
                if flags.contains(.beginConfiguration) {
                    manager.handleDisplayWillChange(displayID: displayID)
                } else {
                    manager.handleDisplayDidChange(displayID: displayID)
                }
            }
        }
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(displayConfigCallback, selfPointer)
    }
    
    private func enumerateDisplays() {
        var displayCount: UInt32 = 0
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(16))
        
        guard CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount) == .success else {
            return
        }
        
        onlineDisplays.prefix(Int(displayCount)).forEach { id in
            displays[id] = DisplayInfo(id: id)
        }
    }
    
    private func handleDisplayWillChange(displayID: CGDirectDisplayID) {
        // Prepare for display configuration changes
        displays[displayID]?.previousState = currentDisplayState(for: displayID)
    }
    
    private func handleDisplayDidChange(displayID: CGDirectDisplayID) {
        // Handle completed display changes
        updateDisplayInfo(for: displayID)
        notifyObservers()
    }
    
    private func currentDisplayState(for displayID: CGDirectDisplayID) -> DisplayState {
        return DisplayState(
            bounds: CGDisplayBounds(displayID),
            mode: CGDisplayCopyDisplayMode(displayID),
            isOnline: CGDisplayIsOnline(displayID) != 0,
            isMain: CGDisplayIsMain(displayID) != 0
        )
    }
    
    private func updateDisplayInfo(for displayID: CGDirectDisplayID) {
        displays[displayID]?.currentState = currentDisplayState(for: displayID)
    }
    
    private func notifyObservers() {
        NotificationCenter.default.post(name: .displayConfigurationChanged, object: nil)
    }
    
    deinit {
        if let callback = displayConfigCallback {
            CGDisplayRemoveReconfigurationCallback(callback, Unmanaged.passUnretained(self).toOpaque())
        }
    }
    
    func fadeToBlack() {
        do {
            try validateDisplayAccess()
            recoveryStatus = .recovering
            
            // Existing fade logic...
            BenchmarkController.shared.measureFlush(displayID: currentDisplayID)
            
            recoveryStatus = .normal
        } catch {
            recoveryStatus = .error(error as? DisplayError ?? .unknown)
        }
    }
    
    func adjustFadeParameters(forPowerState isLowPower: Bool) {
        let params: FadeParameters = isLowPower ? 
            .conservationMode : 
            .defaultMode
        
        FadeController.shared.updateParameters(params)
        
        if isLowPower && isFadeActive {
            GammaController.adjustGammaLevel(
                to: params.safeGammaLevel,
                displayID: currentDisplayID
            )
        }
    }
    
    func updateState(for displayID: CGDirectDisplayID, newState: DisplayState) {
        stateQueue.sync {
            displayStates[displayID] = newState
            SecurityAuditLogger.logStateChange(displayID: displayID, 
                                             oldState: displayStates[displayID],
                                             newState: newState)
        }
    }
}

extension DisplayManager {
    enum DisplayEvent {
        case displayAdded(displayID: CGDirectDisplayID, isMain: Bool)
        case displayRemoved(displayID: CGDirectDisplayID)
        case configurationChanged(displayID: CGDirectDisplayID)
        case configurationError(error: Error)
    }
    
    struct DisplayInfo {
        let id: CGDirectDisplayID
        var previousState: DisplayState?
        var currentState: DisplayState?
    }
    
    enum DisplayState {
        case activeFade(FadeParameters)
        case interruptedFade(FadeParameters)
        case recovering
        case ready
        case error(DisplayError)
    }
    
    enum RecoveryState {
        case normal
        case recovering
        case error(DisplayError)
    }
    
    enum DisplayError: Error {
        case invalidDisplay
        case gammaOutOfBounds
        case systemPolicyRestricted
        case unknown
    }
}

extension NSNotification.Name {
    static let displayConfigurationChanged = Notification.Name("DisplayConfigurationChanged")
}

// MARK: - Display Safety Protocol
protocol DisplaySafetyChecks {
    func validateDisplay(_ displayID: CGDirectDisplayID) -> Bool
    func getActiveDisplays() async -> Set<CGDirectDisplayID>
}

extension DisplayManager: DisplaySafetyChecks {
    func getActiveDisplays() async -> Set<CGDirectDisplayID> {
        activeDisplays
    }
}

// Add security logging structure
struct DisplaySecurityEvent: Codable {
    let timestamp: Date
    let user: String
    let displayID: CGDirectDisplayID
    let action: String
    let context: [String: String]
    var signature: Data?
    
    init(displayID: CGDirectDisplayID, action: String, context: [String: String]) {
        self.timestamp = Date()
        self.user = NSUserName()
        self.displayID = displayID
        self.action = action
        self.context = context
        self.signature = try? generateSignature()
    }
    
    private func generateSignature() throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            SecKeyCopyPublicKey(SecKeyCreateRandomKey(.rsa, 2048, nil)!),
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) else {
            throw error!.takeRetainedValue()
        }
        return signature as Data
    }
}

// Add Keychain helper
struct Keychain {
    static func save(key: String, data: Data) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as CFDictionary
        
        SecItemDelete(query)
        return SecItemAdd(query, nil)
    }
    
    static func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as CFDictionary
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)
        
        guard status == errSecSuccess else { return nil }
        return dataTypeRef as? Data
    }
} 