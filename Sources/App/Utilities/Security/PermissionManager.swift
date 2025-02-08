import Foundation
import Combine
import CoreGraphics

actor PermissionManager {
    static let shared = PermissionManager()
    
    private var authorizationSubject = CurrentValueSubject<Bool, Never>(false)
    private let securityLogger = OSLog(subsystem: "com.yourapp.security", category: "Permissions")
    
    nonisolated var authorizationStatus: AnyPublisher<Bool, Never> {
        shared.authorizationSubject.eraseToAnyPublisher()
    }
    
    private init() {
        Task { await updateAuthorizationStatus() }
    }
    
    func requestAccess() async throws {
        let status = await checkAuthorizationStatus()
        
        guard !status else {
            OSLog.debug("Screen recording permission already granted", log: securityLogger)
            return
        }
        
        let result = await withCheckedContinuation { continuation in
            CGRequestScreenCaptureAccess { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard result else {
            OSLog.error("Screen recording permission denied by user", log: securityLogger)
            throw PermissionError.deniedByUser
        }
        
        await updateAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() async -> Bool {
        let status = CGPreflightScreenCaptureAccess()
        await MainActor.run { authorizationSubject.send(status) }
        return status
    }
    
    private func updateAuthorizationStatus() {
        let currentStatus = CGPreflightScreenCaptureAccess()
        authorizationSubject.send(currentStatus)
    }
    
    func openSystemPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenRecording")!)
    }
}

extension PermissionManager {
    enum PermissionError: LocalizedError {
        case deniedByUser
        case restrictedBySystem
        case unexpectedStatus
        
        var errorDescription: String? {
            switch self {
            case .deniedByUser:
                return "Screen recording permission was denied. Please enable in System Settings."
            case .restrictedBySystem:
                return "Screen recording access is restricted by system policies."
            case .unexpectedStatus:
                return "Unexpected authorization status received."
            }
        }
    }
}

// MARK: - Authorization Protocol
protocol SystemAuthorization {
    func requestScreenCaptureAccess(completionHandler handler: @escaping (Bool) -> Void)
    func preflightScreenCaptureAccess() -> Bool
}

extension PermissionManager: SystemAuthorization {
    func requestScreenCaptureAccess(completionHandler handler: @escaping (Bool) -> Void) {
        CGRequestScreenCaptureAccess(handler)
    }
    
    func preflightScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
} 