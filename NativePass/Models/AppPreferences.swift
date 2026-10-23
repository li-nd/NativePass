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
    nonisolated static let defaultPasswordLength = 25
    nonisolated static let defaultClipboardTimeout: TimeInterval = 45
    nonisolated static let defaultRevealHideDelay: TimeInterval = 30
    nonisolated static let defaultAutoTypeDelayMilliseconds = 200

    static var generatedPasswordLength: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "generatedPasswordLength")
            return stored == 0 ? defaultPasswordLength : stored
        }
        set {
            let clamped = min(
                max(newValue, PasswordGeneratorOptions.minimumLength),
                PasswordGeneratorOptions.maximumLength
            )
            UserDefaults.standard.set(clamped, forKey: "generatedPasswordLength")
        }
    }

    static var passwordGeneratorIncludeUppercase: Bool {
        get { bool(forKey: "passwordGeneratorIncludeUppercase", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "passwordGeneratorIncludeUppercase") }
    }

    static var passwordGeneratorIncludeLowercase: Bool {
        get { bool(forKey: "passwordGeneratorIncludeLowercase", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "passwordGeneratorIncludeLowercase") }
    }

    static var passwordGeneratorIncludeDigits: Bool {
        get { bool(forKey: "passwordGeneratorIncludeDigits", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "passwordGeneratorIncludeDigits") }
    }

    static var passwordGeneratorIncludeSymbols: Bool {
        get { bool(forKey: "passwordGeneratorIncludeSymbols", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "passwordGeneratorIncludeSymbols") }
    }

    static var passwordGeneratorAvoidAmbiguous: Bool {
        get { bool(forKey: "passwordGeneratorAvoidAmbiguous", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "passwordGeneratorAvoidAmbiguous") }
    }

    static var passwordGeneratorOptions: PasswordGeneratorOptions {
        get {
            PasswordGeneratorOptions(
                length: generatedPasswordLength,
                includeUppercase: passwordGeneratorIncludeUppercase,
                includeLowercase: passwordGeneratorIncludeLowercase,
                includeDigits: passwordGeneratorIncludeDigits,
                includeSymbols: passwordGeneratorIncludeSymbols,
                avoidAmbiguous: passwordGeneratorAvoidAmbiguous
            )
        }
        set {
            generatedPasswordLength = newValue.clampedLength
            passwordGeneratorIncludeUppercase = newValue.includeUppercase
            passwordGeneratorIncludeLowercase = newValue.includeLowercase
            passwordGeneratorIncludeDigits = newValue.includeDigits
            passwordGeneratorIncludeSymbols = newValue.includeSymbols
            passwordGeneratorAvoidAmbiguous = newValue.avoidAmbiguous
        }
    }

    private static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
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

    /// When true, the Quick Access field picker shows short value previews (and live OTP).
    static var showQuickAccessFieldPreviews: Bool {
        get {
            if UserDefaults.standard.object(forKey: "showQuickAccessFieldPreviews") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "showQuickAccessFieldPreviews")
        }
        set { UserDefaults.standard.set(newValue, forKey: "showQuickAccessFieldPreviews") }
    }

    /// When true, the app uses `.accessory` activation policy (no Dock icon).
    static var hideFromDock: Bool {
        get { UserDefaults.standard.bool(forKey: "hideFromDock") }
        set { UserDefaults.standard.set(newValue, forKey: "hideFromDock") }
    }
}
