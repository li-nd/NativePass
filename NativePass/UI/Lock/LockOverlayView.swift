import AppKit
import SwiftUI

struct LockOverlayView: View {
    @Environment(AppState.self) private var appState
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("NativePass is Locked")
                    .font(.title2)

                if isAuthenticating {
                    ProgressView("Waiting for authentication…")
                        .controlSize(.small)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await unlockManually() }
                } label: {
                    Label("Unlock", systemImage: "touchid")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
            }
            .padding()
        }
        .task(id: appState.appLock.lockSession) {
            await attemptAutoUnlock()
        }
    }

    private func attemptAutoUnlock() async {
        guard appState.appLock.shouldAttemptAutoUnlock() else { return }

        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        prepareWindowForAuthentication()
        try? await Task.sleep(for: .milliseconds(150))

        let outcome = await appState.appLock.authenticateForAutoUnlock()
        switch outcome {
        case .failed:
            errorMessage = "Authentication failed."
        case .unavailable:
            errorMessage = String(localized: "Authentication isn't available. Set a login password or Touch ID in System Settings to unlock.")
        case .success, .cancelled:
            break
        }
    }

    private func unlockManually() async {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        prepareWindowForAuthentication()

        let outcome = await appState.appLock.authenticateForManualUnlock()
        switch outcome {
        case .success:
            break
        case .cancelled:
            break
        case .failed:
            errorMessage = "Authentication failed."
        case .unavailable:
            errorMessage = String(localized: "Authentication isn't available. Set a login password or Touch ID in System Settings to unlock.")
        }
    }

    private func prepareWindowForAuthentication() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
