import AppKit

enum DockVisibility {
    static func applyFromPreferences() {
        sync()
    }

    /// Preference toggle changed.
    static func apply(hide: Bool) {
        if !hide {
            setPolicy(.regular, activate: true)
            return
        }
        sync()
    }

    /// Switch to `.regular` before ordering a main/settings window front when Dock is hidden,
    /// so the menu bar is available immediately.
    static func prepareForShowingWindow() {
        guard AppPreferences.hideFromDock else { return }
        setPolicy(.regular, activate: true)
    }

    /// Keep menu bar while a real window is visible; use `.accessory` otherwise when hiding from Dock.
    static func sync() {
        guard AppPreferences.hideFromDock else {
            setPolicy(.regular, activate: false)
            return
        }

        if hasMenuEligibleWindow {
            setPolicy(.regular, activate: false)
        } else {
            setPolicy(.accessory, activate: false)
        }
    }

    private static func setPolicy(_ policy: NSApplication.ActivationPolicy, activate: Bool) {
        guard NSApp.activationPolicy() != policy else {
            if activate {
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }
        _ = NSApp.setActivationPolicy(policy)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Main / Settings windows — not Quick Access (`NSPanel`) or other panels.
    private static var hasMenuEligibleWindow: Bool {
        NSApp.windows.contains { isMenuEligible($0) }
    }

    private static func isMenuEligible(_ window: NSWindow) -> Bool {
        if window is NSPanel { return false }
        guard window.isVisible, !window.isMiniaturized else { return false }
        if window.identifier?.rawValue == AppWindowID.main { return true }
        if window.identifier?.rawValue == AppWindowID.settings { return true }
        if window.title.localizedCaseInsensitiveContains("settings") { return true }
        let className = String(describing: type(of: window))
        if className.localizedCaseInsensitiveContains("Settings") { return true }
        return window.canBecomeMain
    }
}
