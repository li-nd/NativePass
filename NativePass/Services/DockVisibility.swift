import AppKit

enum DockVisibility {
    static func applyFromPreferences() {
        apply(hide: AppPreferences.hideFromDock)
    }

    static func apply(hide: Bool) {
        let policy: NSApplication.ActivationPolicy = hide ? .accessory : .regular
        _ = NSApp.setActivationPolicy(policy)
        if !hide {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
