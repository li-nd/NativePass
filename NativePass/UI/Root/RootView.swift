import Combine
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismissWindow) private var dismissWindow

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                appState.appLock.lockFromBackground()
            } else if newPhase == .active {
                appState.appLock.checkIdleLock()
                if !appState.appLock.isBlocking {
                    Task { await appState.refreshOnActivate() }
                }
            }
        }
        .onChange(of: appState.appLock.isLocked) { _, locked in
            if locked {
                dismissWindow(id: "settings")
                appState.purgeSensitiveStateOnLock()
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            guard scenePhase == .active, appState.appLock.isEnabled else { return }
            appState.appLock.checkIdleLock()
        }
    }
}
