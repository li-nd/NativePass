import AppKit
import ApplicationServices
import Carbon
import Foundation

enum AutoTypeError: LocalizedError {
    case accessibilityNotGranted
    case emptyText

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            String(localized: "Accessibility permission is required for Auto-Type.")
        case .emptyText:
            String(localized: "Nothing to type.")
        }
    }
}

enum AutoTypeService {
    /// Modifiers that break HID unicode typing if still held (⌘↵ Auto-Type).
    private static let typeBlockingModifiers: CGEventFlags = [.maskCommand]

    static func isTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @MainActor
    static func areTypeBlockingModifiersPressed() -> Bool {
        let flags = CGEventSource.flagsState(.hidSystemState)
        return !flags.intersection(typeBlockingModifiers).isEmpty
    }

    /// Waits until ⌘ is released, `shouldContinue` becomes false, or timeout.
    /// Returns `true` if modifiers were released cleanly.
    @MainActor
    static func waitForTypeBlockingModifiersReleased(
        timeoutMilliseconds: UInt64 = 5_000,
        shouldContinue: @MainActor () -> Bool = { true }
    ) async -> Bool {
        let deadline = ContinuousClock.now + .milliseconds(timeoutMilliseconds)
        while ContinuousClock.now < deadline {
            guard shouldContinue() else { return false }
            if !areTypeBlockingModifiersPressed() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
        return !areTypeBlockingModifiersPressed()
    }

    @MainActor
    static func waitUntilFrontmost(
        _ application: NSRunningApplication,
        timeoutMilliseconds: UInt64 = 800
    ) async {
        let deadline = ContinuousClock.now + .milliseconds(timeoutMilliseconds)
        while ContinuousClock.now < deadline {
            if application.isTerminated { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                return
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    /// Posts keystrokes to the frontmost application via HID events.
    @MainActor
    static func typeText(_ text: String) throws {
        guard isTrusted(prompt: false) else {
            throw AutoTypeError.accessibilityNotGranted
        }
        guard !text.isEmpty else {
            throw AutoTypeError.emptyText
        }

        for scalar in text.unicodeScalars {
            switch scalar {
            case "\n", "\r":
                postVirtualKey(UInt16(kVK_Return))
            case "\t":
                postVirtualKey(UInt16(kVK_Tab))
            default:
                postUnicodeScalar(scalar)
            }
            // Tiny gap helps Terminal and some secure fields keep up.
            usleep(8_000)
        }
    }

    private static func postUnicodeScalar(_ scalar: Unicode.Scalar) {
        var chars = Array(String(scalar).utf16)
        chars.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            down?.post(tap: .cghidEventTap)

            let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            up?.post(tap: .cghidEventTap)
        }
    }

    private static func postVirtualKey(_ keyCode: UInt16) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        up?.post(tap: .cghidEventTap)
    }
}
