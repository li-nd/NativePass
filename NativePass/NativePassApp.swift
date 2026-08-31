import AppKit
import SwiftUI

@main
struct NativePassApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    init() {
        AppLanguage.applyStoredPreference()
    }

    private var isBlocking: Bool {
        appState.appLock.isBlocking
    }

    private var preferredLocale: Locale {
        switch AppLanguage.preference {
        case .system:
            return .autoupdatingCurrent
        default:
            return Locale(identifier: AppLanguage.preference.rawValue)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.locale, preferredLocale)
        }
        .defaultSize(width: 960, height: 640)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppMetadata.applicationName)") {
                    AppMetadata.showAboutPanel()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    guard !isBlocking else { return }
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(isBlocking)
            }

            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    NotificationCenter.default.post(name: Notification.Name.nativePassNewEntry, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(isBlocking)
            }

            CommandMenu("Entry") {
                Button("Focus Search") {
                    NotificationCenter.default.post(name: Notification.Name.nativePassFocusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(isBlocking)

                Button("Copy Password") {
                    NotificationCenter.default.post(name: Notification.Name.nativePassCopyPassword, object: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(isBlocking)

                Button("Copy Raw Entry") {
                    NotificationCenter.default.post(name: Notification.Name.nativePassCopyRawEntry, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(isBlocking)
            }

            CommandMenu("Sync") {
                Button("Pull") {
                    NotificationCenter.default.post(name: Notification.Name.nativePassGitPull, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.control, .command, .shift])
                .disabled(isBlocking)

                Button("Push") {
                    NotificationCenter.default.post(name: Notification.Name.nativePassGitPush, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.control, .command])
                .disabled(isBlocking)
            }

            CommandGroup(after: .appSettings) {
                Button("Lock Now") {
                    appState.appLock.lockManually()
                }
                .keyboardShortcut("l", modifiers: [.control, .command])
                .disabled(!appState.appLock.isEnabled || isBlocking)
            }
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .environment(appState)
                .environment(\.locale, preferredLocale)
        }
        .defaultSize(width: 520, height: 420)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra("NativePass", systemImage: "key") {
            Button("Quick Access") {
                appState.quickAccess.toggle()
            }
            .keyboardShortcut("p", modifiers: [.option, .command])

            Button("Open NativePass") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
