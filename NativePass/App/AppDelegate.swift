import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockVisibility.applyFromPreferences()
        observeWindowFocusChanges()
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
        let handler: (Notification) -> Void = { _ in
            DispatchQueue.main.async {
                DockVisibility.sync()
            }
        }
        center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main, using: handler)
        center.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main, using: handler)
        center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main, using: handler)
        center.addObserver(forName: NSWindow.didMiniaturizeNotification, object: nil, queue: .main, using: handler)
        center.addObserver(forName: NSWindow.didDeminiaturizeNotification, object: nil, queue: .main, using: handler)
    }
}
