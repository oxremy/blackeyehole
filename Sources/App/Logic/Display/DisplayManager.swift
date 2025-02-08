import Combine
import CoreGraphics
import Foundation

actor DisplayManager {
    static let shared = DisplayManager()
    
    private var activeDisplays: Set<CGDirectDisplayID> = []
    private var reconfigurationCallback: CGDisplayReconfigurationCallBack?
    private let displaySubject = PassthroughSubject<DisplayEvent, Never>()
    private var validSerialNumbers: Set<String> = []
    
    nonisolated var displayEvents: AnyPublisher<DisplayEvent, Never> {
        displaySubject.eraseToAnyPublisher()
    }
    
    private init() {
        configureSerialNumberValidation()
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
            if flags.contains(.addFlag) && isValid {
                activeDisplays.insert(displayID)
                displaySubject.send(.displayAdded(displayID: displayID, isMain: isMainDisplay))
            } else if flags.contains(.removeFlag) {
                activeDisplays.remove(displayID)
                displaySubject.send(.displayRemoved(displayID: displayID))
            }
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
            return false
        }
        return validSerialNumbers.contains(serialNumber)
    }
    
    private func getDisplaySerialNumber(_ displayID: CGDirectDisplayID) -> String? {
        guard let info = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() else {
            return nil
        }
        
        return (info[kDisplayProductID] as? NSNumber)?.stringValue
    }
    
    private func retrieveValidDisplaySerialNumbers() -> Set<String> {
        // Implementation would integrate with system validation
        // Placeholder for actual validation logic
        return ["default"]
    }
}

extension DisplayManager {
    enum DisplayEvent {
        case displayAdded(displayID: CGDirectDisplayID, isMain: Bool)
        case displayRemoved(displayID: CGDirectDisplayID)
        case configurationChanged(displayID: CGDirectDisplayID)
    }
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