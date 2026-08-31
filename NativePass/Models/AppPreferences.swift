import Foundation

enum QuickAccessPrimaryAction: String, CaseIterable, Identifiable {
    case copy
    case autoType

    var id: String { rawValue }

    var label: String {
        switch self {
        case .copy: String(localized: "Copy Password")
        case .autoType: String(localized: "Type Password")
        }
    }
}

enum AppPreferences {
    static let defaultPasswordLength = 25
    static let defaultClipboardTimeout: TimeInterval = 45
    static let defaultRevealHideDelay: TimeInterval = 30
    static let defaultAutoTypeDelayMilliseconds = 200

    static var generatedPasswordLength: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "generatedPasswordLength")
            return stored == 0 ? defaultPasswordLength : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: "generatedPasswordLength") }
    }

    static var clipboardClearTimeout: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: "clipboardClearTimeout")
            return stored == 0 ? defaultClipboardTimeout : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: "clipboardClearTimeout") }
    }

    static var revealHideDelay: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: "revealHideDelay")
            return stored == 0 ? defaultRevealHideDelay : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: "revealHideDelay") }
    }

    static var autoTypeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoTypeEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "autoTypeEnabled") }
    }

    static var quickAccessPrimaryAction: QuickAccessPrimaryAction {
        get {
            let raw = UserDefaults.standard.string(forKey: "quickAccessPrimaryAction") ?? ""
            return QuickAccessPrimaryAction(rawValue: raw) ?? .copy
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "quickAccessPrimaryAction") }
    }

    /// Effective primary action — Auto-Type only when enabled.
    static var effectiveQuickAccessPrimaryAction: QuickAccessPrimaryAction {
        guard autoTypeEnabled else { return .copy }
        return quickAccessPrimaryAction
    }

    static var autoTypeDelayMilliseconds: Int {
        get {
            if UserDefaults.standard.object(forKey: "autoTypeDelayMilliseconds") == nil {
                return defaultAutoTypeDelayMilliseconds
            }
            return UserDefaults.standard.integer(forKey: "autoTypeDelayMilliseconds")
        }
        set {
            let clamped = min(max(newValue, 0), 1_000)
            UserDefaults.standard.set(clamped, forKey: "autoTypeDelayMilliseconds")
        }
    }
}
