import AppKit
import Foundation

/// In-app language override. Empty preference means follow the system language.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = ""
    case english = "en"
    case russian = "ru"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case portugueseBrazil = "pt-BR"
    case italian = "it"
    case korean = "ko"
    case dutch = "nl"
    case polish = "pl"
    case ukrainian = "uk"

    var id: String { rawValue }

    private static let preferenceKey = "appLanguagePreference"
    private static let appleLanguagesKey = "AppleLanguages"

    /// Stored preference. `.system` is the default when nothing is saved.
    static var preference: AppLanguage {
        get {
            let stored = UserDefaults.standard.string(forKey: preferenceKey) ?? ""
            return AppLanguage(rawValue: stored) ?? .system
        }
        set {
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: preferenceKey)
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey)
            }
        }
    }

    /// Native / English display names for the picker (not localized — they identify the language itself).
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "System")
        case .english:
            return "English"
        case .russian:
            return "Русский"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        case .japanese:
            return "日本語"
        case .chineseSimplified:
            return "简体中文"
        case .portugueseBrazil:
            return "Português (Brasil)"
        case .italian:
            return "Italiano"
        case .korean:
            return "한국어"
        case .dutch:
            return "Nederlands"
        case .polish:
            return "Polski"
        case .ukrainian:
            return "Українська"
        }
    }

    /// English name used for A–Z ordering in the picker (System stays first).
    private var sortName: String {
        switch self {
        case .system: return ""
        case .chineseSimplified: return "Chinese (Simplified)"
        case .dutch: return "Dutch"
        case .english: return "English"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .polish: return "Polish"
        case .portugueseBrazil: return "Portuguese (Brazil)"
        case .russian: return "Russian"
        case .spanish: return "Spanish"
        case .ukrainian: return "Ukrainian"
        }
    }

    /// System first, then languages A–Z by English name.
    static var pickerCases: [AppLanguage] {
        let languages = allCases.filter { $0 != .system }
            .sorted { $0.sortName.localizedStandardCompare($1.sortName) == .orderedAscending }
        return [.system] + languages
    }

    /// Apply the stored preference to `AppleLanguages` so `String(localized:)` and menus follow it.
    static func applyStoredPreference() {
        preference.applyAppleLanguages()
    }

    func applyAppleLanguages() {
        let defaults = UserDefaults.standard
        if self == .system {
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        } else {
            defaults.set([rawValue], forKey: Self.appleLanguagesKey)
        }
        defaults.synchronize()
    }

    /// Persist selection and apply process language. Caller should relaunch for full effect.
    static func select(_ language: AppLanguage) {
        preference = language
        language.applyAppleLanguages()
    }

    static func relaunchApp() {
        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
