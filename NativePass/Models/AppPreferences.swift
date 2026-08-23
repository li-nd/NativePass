import Foundation

enum AppPreferences {
    static let defaultPasswordLength = 25
    static let defaultClipboardTimeout: TimeInterval = 45
    static let defaultRevealHideDelay: TimeInterval = 30

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
}
