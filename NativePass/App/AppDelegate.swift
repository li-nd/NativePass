import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Retained so block-based `NotificationCenter` observers stay registered.
    private var windowObserverTokens: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockVisibility.applyFromPreferences()
        observeWindowFocusChanges()
        Self.applyScreenCapturePreference()
    }

    /// Window sharing type for the current Settings choice. `.none` keeps revealed secrets
    /// out of screenshots, recordings and screen sharing.
    static var preferredSharingType: NSWindow.SharingType {
        AppPreferences.excludeFromScreenCapture ? .none : .readOnly
    }

    static func applyScreenCapturePreference() {
        let sharingType = preferredSharingType
        for window in NSApp.windows where window.sharingType != sharingType {
            window.sharingType = sharingType
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DockVisibility.sync()
    }

    func applicationDidResignActive(_ notification: Notification) {
        // Defer slightly so closing/reopening windows can settle before we drop to accessory.
        DispatchQueue.main.async {
            DockVisibility.sync()
        }
    }

    private func observeWindowFocusChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.willCloseNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
        ]
        let handler: (Notification) -> Void = { _ in
            AppDelegate.applyScreenCapturePreference()
            DispatchQueue.main.async {
                DockVisibility.sync()
            }
        }
        windowObserverTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main, using: handler)
        }
    }
}
