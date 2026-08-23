import SwiftUI

struct SetupView: View {
    @Environment(AppState.self) private var appState

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
                    message: "Run in Terminal: pass init your-gpg-id",
                    icon: "folder.badge.questionmark"
                )
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
            .buttonStyle(.borderedProminent)
            .disabled(appState.isBootstrapping)
        }
        .padding(40)
        .frame(maxWidth: 480)
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
}
