import Foundation
import LocalAuthentication
import Observation

@Observable
final class AppLockService {
    enum LockTimeout: Int, CaseIterable, Identifiable {
        case five = 5
        case fifteen = 15
        case thirty = 30

        var id: Int { rawValue }

        var label: String { String(localized: "\(rawValue) minutes") }
    }

    enum AuthenticationOutcome: Sendable {
        case success
        case cancelled
        case failed
    }

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "appLockEnabled") }
    }

    var timeout: LockTimeout {
        didSet { UserDefaults.standard.set(timeout.rawValue, forKey: "appLockTimeout") }
    }

    private(set) var isLocked = false
    private(set) var lockSession = UUID()
    private var lastActivity = Date()
    private var hasAttemptedAutoUnlock = false
    private var autoUnlockEnabledForCurrentSession = false
    /// Set by background lock; auto Touch ID runs only after the app becomes active again.
    private var pendingAutoUnlockOnActivate = false

    var isBlocking: Bool {
        isEnabled && isLocked
    }

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "appLockEnabled") as? Bool ?? false
        let stored = UserDefaults.standard.integer(forKey: "appLockTimeout")
        timeout = LockTimeout(rawValue: stored == 0 ? 15 : stored) ?? .fifteen
        if isEnabled {
            isLocked = true
            beginLockSession(allowsAutoUnlock: true)
        }
    }

    func recordActivity() {
        guard !isLocked else { return }
        lastActivity = Date()
    }

    func checkIdleLock() {
        lockIfNeeded()
    }

    func lockIfNeeded() {
        guard isEnabled, !isLocked else { return }
        let elapsed = Date().timeIntervalSince(lastActivity)
        if elapsed >= TimeInterval(timeout.rawValue * 60) {
            pendingAutoUnlockOnActivate = false
            setLocked(true, allowsAutoUnlock: true)
        }
    }

    /// User chose Lock Now from the menu — no automatic Touch ID prompt.
    func lockManually() {
        guard isEnabled else { return }
        pendingAutoUnlockOnActivate = false
        setLocked(true, allowsAutoUnlock: false)
    }

    /// App hid / went to background — lock now, prompt only when the user returns.
    func lockFromBackground() {
        guard isEnabled else { return }
        if isLocked {
            // Already locked (e.g. Lock Now, then ⌘H): still defer any auto prompt until activate.
            pendingAutoUnlockOnActivate = true
            autoUnlockEnabledForCurrentSession = false
            return
        }
        pendingAutoUnlockOnActivate = true
        setLocked(true, allowsAutoUnlock: false)
    }

    /// Call when `scenePhase` becomes `.active` so background locks can auto-prompt once.
    func prepareAutoUnlockAfterReturningToForeground() {
        guard isBlocking, pendingAutoUnlockOnActivate else { return }
        pendingAutoUnlockOnActivate = false
        beginLockSession(allowsAutoUnlock: true)
    }

    func enableLock() {
        isEnabled = true
        pendingAutoUnlockOnActivate = false
        setLocked(true, allowsAutoUnlock: false)
        lastActivity = Date()
    }

    func shouldAttemptAutoUnlock() -> Bool {
        isBlocking && autoUnlockEnabledForCurrentSession && !hasAttemptedAutoUnlock
    }

    @MainActor
    func disableLockAfterAuthentication() async -> Bool {
        guard await authenticate(reason: String(localized: "Turn off App Lock"), allowPassword: true) == .success else {
            return false
        }
        isEnabled = false
        isLocked = false
        pendingAutoUnlockOnActivate = false
        return true
    }

    @MainActor
    func updateTimeoutAfterAuthentication(_ newTimeout: LockTimeout) async -> Bool {
        guard newTimeout != timeout else { return true }
        guard await authenticate(reason: String(localized: "Change App Lock settings"), allowPassword: true) == .success else {
            return false
        }
        timeout = newTimeout
        lastActivity = Date()
        return true
    }

    @MainActor
    func authenticateForAutoUnlock() async -> AuthenticationOutcome {
        guard shouldAttemptAutoUnlock() else { return .cancelled }
        hasAttemptedAutoUnlock = true
        return await authenticate(reason: String(localized: "Unlock NativePass"), allowPassword: false)
    }

    @MainActor
    func authenticateForManualUnlock() async -> AuthenticationOutcome {
        await authenticate(reason: String(localized: "Unlock NativePass"), allowPassword: true)
    }

    @MainActor
    func authenticate(reason: String = String(localized: "Unlock NativePass"), allowPassword: Bool = true) async -> AuthenticationOutcome {
        await evaluateAuthentication(reason: reason, allowPassword: allowPassword)
    }

    // MARK: - Private

    private func setLocked(_ locked: Bool, allowsAutoUnlock: Bool) {
        if locked && !isLocked {
            beginLockSession(allowsAutoUnlock: allowsAutoUnlock)
        }
        isLocked = locked
    }

    private func beginLockSession(allowsAutoUnlock: Bool) {
        lockSession = UUID()
        hasAttemptedAutoUnlock = false
        autoUnlockEnabledForCurrentSession = allowsAutoUnlock
    }

    @MainActor
    private func evaluateAuthentication(reason: String, allowPassword: Bool) async -> AuthenticationOutcome {
        let context = LAContext()
        var error: NSError?

        let policy: LAPolicy?
        if allowPassword {
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                policy = .deviceOwnerAuthentication
            } else {
                policy = nil
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else {
            policy = nil
        }

        guard let policy else {
            if allowPassword {
                unlockAfterAuthentication()
                return .success
            }
            return .failed
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                unlockAfterAuthentication()
                return .success
            }
            return .failed
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .systemCancel, .appCancel:
                return .cancelled
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    private func unlockAfterAuthentication() {
        isLocked = false
        pendingAutoUnlockOnActivate = false
        lastActivity = Date()
    }
}
