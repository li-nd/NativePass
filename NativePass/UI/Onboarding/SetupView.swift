import AppKit
import SwiftUI

struct SetupView: View {
    @Environment(AppState.self) private var appState

    @State private var showCreateSheet = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Setup Required")
                .font(.largeTitle)

            if !appState.environment.isPassAvailable {
                setupCard(
                    title: "pass not found",
                    message: "Install pass via Homebrew: brew install pass",
                    icon: "terminal"
                )
            } else if !appState.environment.isStoreInitialized {
                setupCard(
                    title: "Password store not initialized",
                    message: "Create a new store or choose an existing password-store folder.",
                    icon: "folder.badge.questionmark"
                )

                VStack(spacing: 12) {
                    Button("Create New Store…") {
                        showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Choose Existing Folder…") {
                        chooseExisting()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if let report = appState.systemReport, !report.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warnings")
                        .font(.headline)
                    ForEach(report.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button("Check Again") {
                Task { await appState.bootstrap() }
            }
            .disabled(appState.isBootstrapping)
        }
        .padding(40)
        .frame(maxWidth: 520)
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                StoreKeySetupSheet(mode: .create) {
                    Task { await appState.bootstrap() }
                }
            }
            .environment(appState)
        }
    }

    private func setupCard(title: String, message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func chooseExisting() {
        errorMessage = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = StoreRegistry.defaultStoreURL
        panel.message = String(localized: "Select a password store folder (contains .gpg-id).")
        panel.prompt = String(localized: "Open")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let gpgID = url.appendingPathComponent(".gpg-id")
        if !FileManager.default.fileExists(atPath: gpgID.path) {
            errorMessage = String(
                localized: "That folder has no .gpg-id. Create a new store or choose an initialized folder."
            )
            return
        }

        Task {
            await appState.addExistingStore(url)
        }
    }
}
