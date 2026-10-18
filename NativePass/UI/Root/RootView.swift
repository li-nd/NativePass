import AppKit
import Combine
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    @State private var storeSetupMode: StoreKeySetupMode?
    @State private var storeActionError: String?

    var body: some View {
        Group {
            if appState.appLock.isBlocking {
                LockOverlayView()
            } else if appState.isBootstrapping {
                BootstrapLoadingView(step: appState.bootstrapStep)
            } else if !appState.isReady {
                SetupView()
            } else {
                MainView()
                    .onTapGesture {
                        appState.appLock.recordActivity()
                    }
            }
        }
        .task {
            await appState.bootstrap()
        }
        .onAppear {
            appState.bindOpenMainWindow {
                openWindow(id: AppWindowID.main)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.appLock.checkIdleLock()
                if !appState.appLock.isBlocking {
                    Task { await appState.refreshOnActivate() }
                }
            }
        }
        .onChange(of: appState.appLock.isLocked) { _, locked in
            if locked {
                dismissWindow(id: AppWindowID.settings)
                appState.purgeSensitiveStateOnLock()
                storeSetupMode = nil
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            guard scenePhase == .active, appState.appLock.isEnabled else { return }
            appState.appLock.checkIdleLock()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassCreateStore)) { _ in
            guard !appState.appLock.isBlocking else { return }
            storeSetupMode = .create
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassAddExistingStore)) { _ in
            addExistingStore()
        }
        .sheet(item: $storeSetupMode) { mode in
            NavigationStack {
                StoreKeySetupSheet(mode: mode)
            }
            .environment(appState)
        }
        .alert("Store", isPresented: .init(
            get: { storeActionError != nil },
            set: { if !$0 { storeActionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storeActionError ?? "")
        }
    }

    private func addExistingStore() {
        guard !appState.appLock.isBlocking else { return }
        storeActionError = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = StoreRegistry.defaultStoreURL
        panel.message = String(localized: "Select a password store folder.")
        panel.prompt = String(localized: "Add")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let gpgID = url.appendingPathComponent(".gpg-id")
        if !FileManager.default.fileExists(atPath: gpgID.path) {
            storeActionError = String(
                localized: "That folder has no .gpg-id. Use Create Store… to initialize it first."
            )
            return
        }

        Task {
            await appState.addExistingStore(url)
        }
    }
}
