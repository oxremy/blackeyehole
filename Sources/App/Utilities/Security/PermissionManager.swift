import Foundation
import Combine
import CoreGraphics
import Security

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    private var authorizationSubject = CurrentValueSubject<Bool, Never>(false)
    private let securityLogger = OSLog(subsystem: "com.yourapp.security", category: "Permissions")
    
    private var auditLog: [SecurityEvent] = []
    private let auditQueue = DispatchQueue(label: "com.yourapp.audit", qos: .utility)
    
    // Add audit trail logging
    private let auditLogger = SecurityAuditLogger()
    
    nonisolated var authorizationStatus: AnyPublisher<Bool, Never> {
        shared.authorizationSubject.eraseToAnyPublisher()
    }
    
    private init() {
        loadAuditHistory()
        Task { await updateAuthorizationStatus() }
    }
    
    func requestAccess() async throws {
        let status = await checkAuthorizationStatus()
        
        guard !status else {
            logSecurityEvent(decision: "already_granted", context: [:])
            return
        }
        
        if CGPreflightScreenCaptureAccess() == false {
            logSecurityEvent(decision: "system_restricted", context: [:])
            throw PermissionError.restrictedBySystem
        }
        
        let result = await withCheckedContinuation { continuation in
            CGRequestScreenCaptureAccess { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard result else {
            logSecurityEvent(decision: "user_denied", context: [:])
            throw PermissionError.deniedByUser
        }
        
        await updateAuthorizationStatus()
        logSecurityEvent(decision: "granted", context: [:])
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
    
    private func loadAuditHistory() {
        auditQueue.sync {
            if let data = UserDefaults.standard.data(forKey: "securityAuditLog"),
               let decoded = try? JSONDecoder().decode([SecurityEvent].self, from: data) {
                auditLog = decoded
            }
        }
    }
    
    private func saveAuditHistory() {
        auditQueue.async { [weak self] in
            guard let self else { return }
            if let data = try? JSONEncoder().encode(self.auditLog) {
                UserDefaults.standard.set(data, forKey: "securityAuditLog")
            }
        }
    }
    
    private func logSecurityEvent(decision: String, context: [String: String]) {
        let event = SecurityEvent(
            timestamp: Date(),
            user: NSUserName(),
            decision: decision,
            context: context
        )
        
        auditLog.append(event)
        saveAuditHistory()
        
        OSLog.info("Security event: %{public}@",
                   log: securityLogger,
                   type: .default,
                   "\(decision) - \(context)")
    }
    
    /// Async version of screen recording permission request
    @available(macOS 10.15, *)
    func requestScreenRecordingPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            CGRequestScreenCaptureAccess() { [weak self] granted, error in
                guard let self else {
                    continuation.resume(throwing: PermissionError.appShutdown)
                    return
                }
                
                if let error = error as NSError? {
                    continuation.resume(throwing: self.handleAuthError(error))
                } else {
                    self.isScreenRecordingAllowed = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // Preserve existing completion handler version for compatibility
    @objc func requestScreenRecordingPermission(completion: @escaping (Bool, Error?) -> Void) {
        if #available(macOS 10.15, *) {
            Task {
                do {
                    let granted = try await requestScreenRecordingPermission()
                    completion(granted, nil)
                } catch {
                    completion(false, error)
                }
            }
        } else {
            CGRequestScreenCaptureAccess() { granted, error in
                completion(granted, error)
            }
        }
    }
    
    func requestScreenCaptureAccess() async -> Bool {
        let status = await CGRequestScreenCaptureAccess()
        
        // Log permission request
        auditLogger.log(event: .screenCaptureAccessRequested(granted: status))
        
        // Store in Keychain if granted
        if status {
            storePermissionStateInKeychain()
        }
        
        return status
    }
    
    private func storePermissionStateInKeychain() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "screen-capture-permission",
            kSecValueData: Data("granted".utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    // New error handling
    enum PermissionError: Error {
        case accessDenied
        case keychainFailure
        case securityFrameworkError(OSStatus)
    }
}

extension PermissionManager {
    enum PermissionError: LocalizedError {
        case deniedByUser
        case restrictedBySystem
        case unexpectedStatus
        case securityViolation
        case appShutdown
        case systemPolicyRestricted
        case userCancelledAuthorization
        
        var errorDescription: String? {
            switch self {
            case .deniedByUser:
                return NSLocalizedString("SCREEN_RECORDING_DENIED", comment: "Permission denied")
            case .restrictedBySystem:
                return NSLocalizedString("SYSTEM_RESTRICTION", comment: "System policy restriction")
            case .unexpectedStatus:
                return NSLocalizedString("UNEXPECTED_AUTH_STATUS", comment: "Unexpected authorization state")
            case .securityViolation:
                return NSLocalizedString("SECURITY_VIOLATION", comment: "Security protocol violation")
            case .appShutdown:
                return NSLocalizedString("APP_SHUTDOWN", comment: "Application shutdown")
            case .systemPolicyRestricted:
                return NSLocalizedString("SYSTEM_POLICY_RESTRICTED", comment: "System policy restricted")
            case .userCancelledAuthorization:
                return NSLocalizedString("USER_CANCELLED_AUTHORIZATION", comment: "User cancelled authorization")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .deniedByUser:
                return NSLocalizedString("CHECK_PRIVACY_SETTINGS", comment: "Check system privacy settings")
            case .restrictedBySystem:
                return NSLocalizedString("CONTACT_ADMIN", comment: "Contact system administrator")
            case .appShutdown:
                return NSLocalizedString("RESTART_APPLICATION", comment: "Try restarting the application")
            case .systemPolicyRestricted:
                return NSLocalizedString("RESTART_APPLICATION", comment: "Try restarting the application")
            case .userCancelledAuthorization:
                return NSLocalizedString("RESTART_APPLICATION", comment: "Try restarting the application")
            default:
                return NSLocalizedString("RESTART_APPLICATION", comment: "Try restarting the application")
            }
        }
        
        var failureReason: String? {
            switch self {
            case .deniedByUser:
                return "User explicitly denied screen recording permission"
            case .restrictedBySystem:
                return "MDM policy or system configuration prevents access"
            case .unexpectedStatus:
                return "Authorization status inconsistent with system state"
            case .securityViolation:
                return "Invalid security event signature detected"
            case .appShutdown:
                return "Application shutdown"
            case .systemPolicyRestricted:
                return "MDM policy or system configuration prevents access"
            case .userCancelledAuthorization:
                return "User cancelled authorization"
            }
        }
    }
    
    private func handleAuthError(_ error: NSError) -> PermissionError {
        switch error.code {
        case -60005: return .systemPolicyRestricted
        case -60006: return .userCancelledAuthorization
        default: return error as! PermissionError
        }
    }
}

// MARK: - Authorization Protocol
protocol SystemAuthorization: AnyObject {
    func requestScreenCaptureAccess(completionHandler handler: @escaping (Bool) -> Void)
    func preflightScreenCaptureAccess() -> Bool
    func logSecurityEvent(decision: String, context: [String: String]) async
}

extension PermissionManager: SystemAuthorization {
    func requestScreenCaptureAccess(completionHandler handler: @escaping (Bool) -> Void) {
        CGRequestScreenCaptureAccess(handler)
    }
    
    func preflightScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    func logSecurityEvent(decision: String, context: [String: String]) async {
        let event = SecurityEvent(
            timestamp: Date(),
            user: NSUserName(),
            decision: decision,
            context: context
        )
        auditLog.append(event)
        saveAuditHistory()
    }
}

struct SecurityEvent: Codable {
    let timestamp: Date
    let user: String
    let decision: String
    let context: [String: String]
    var signature: Data?
    
    init(timestamp: Date, user: String, decision: String, context: [String: String]) {
        self.timestamp = timestamp
        self.user = user
        self.decision = decision
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

// New audit logging component
private struct SecurityAuditLogger {
    enum AuditEvent {
        case screenCaptureAccessRequested(granted: Bool)
        case gammaTableModified(displayID: CGDirectDisplayID)
    }
    
    func log(event: AuditEvent) {
        // Implementation would write to secure log file
    }
}

func requestScreenRecordingPermission() async throws {
    // Existing permission logic...
    
    await SecurityAuditLogger.shared.log(event: SecurityAuditEvent(
        timestamp: Date(),
        type: .permissionChanged,
        user: NSUserName(),
        displayID: nil,
        parameters: ["newStatus": hasPermission]
    ))
} 