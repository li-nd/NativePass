import SwiftUI
import AppKit

struct SystemDiagnosticsView: View {
    @Environment(AppState.self) private var appState
    @State private var testDecryptMessage: String?
    @State private var testDecryptGuide: DecryptRecoveryGuide?
    @State private var gitStatus: GitStatus?
    @State private var isLoadingGit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let report = appState.systemReport {
                    passSection(report)
                    if report.isGitRepository {
                        gitSection
                    }
                    gpgSection(report)
                    pluginsSection(report)
                    environmentSection(report)
                    actionsSection(report)
                } else {
                    ContentUnavailableView {
                        Label("No Diagnostic Data", systemImage: "stethoscope")
                    } description: {
                        Text("Run a system check to inspect pass and plugins.")
                    } actions: {
                        rerunDiagnosticsButton(title: "Run Diagnostics")
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Diagnostics")
        .task {
            if appState.environment.isGitRepository {
                await loadGitStatus()
            }
        }
    }

    @ViewBuilder
    private var gitSection: some View {
        GroupBox("Git") {
            VStack(alignment: .leading, spacing: 8) {
                if isLoadingGit {
                    ProgressView().controlSize(.small)
                } else if let gitStatus {
                    if let branch = gitStatus.branch {
                        infoRow("Branch", branch)
                    }
                    statusRow("Working tree", gitStatus.isClean ? "Clean" : "Dirty", ok: gitStatus.isClean)
                    if !gitStatus.isClean {
                        infoRow("Changed files", "\(gitStatus.changedFilesCount)")
                    }
                } else {
                    Text("Could not load git status.")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Git Status") {
                    Task { await loadGitStatus() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadGitStatus() async {
        guard let git = appState.git else { return }
        isLoadingGit = true
        defer { isLoadingGit = false }
        gitStatus = try? await git.status()
    }

    // MARK: - Sections (pass)

    @ViewBuilder
    private func passSection(_ report: SystemReport) -> some View {
        GroupBox("Pass") {
            VStack(alignment: .leading, spacing: 8) {
                statusRow("Status", report.passAvailable ? "Found" : "Not found", ok: report.passAvailable)
                if let version = report.passVersion {
                    infoRow("Version", version)
                }
                if let path = report.passPath {
                    infoRow("Path", path)
                }
                infoRow("Store", report.storePath)
                statusRow("Initialized", report.storeInitialized ? "Yes" : "No", ok: report.storeInitialized)
                if let count = report.entryCount {
                    infoRow("Entries", "\(count)")
                }
                infoRow("Git", report.isGitRepository ? "Yes" : "No")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func gpgSection(_ report: SystemReport) -> some View {
        GroupBox("GPG") {
            VStack(alignment: .leading, spacing: 8) {
                infoRow("Binary", report.gpgBinary)
                if let version = report.gpgVersion {
                    infoRow("Version", version)
                }
                if !report.gpgIDs.isEmpty {
                    infoRow("Recipient IDs", report.gpgIDs.joined(separator: ", "))
                }
                if let pinentry = report.pinentryProgram {
                    infoRow("Pinentry", pinentry)
                } else {
                    Text("Install pinentry-mac and set pinentry-program in ~/.gnupg/gpg-agent.conf for Touch ID with GPG.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func pluginsSection(_ report: SystemReport) -> some View {
        GroupBox("Plugins") {
            if report.plugins.isEmpty {
                Text("No pass extensions found.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(report.plugins) { plugin in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(plugin.displayName)
                                    .font(.headline)
                                Text("(\(plugin.command))")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                pluginStatusBadge(plugin)
                            }
                            if let path = plugin.filePath?.path {
                                Text(path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            if !plugin.capabilities.isEmpty {
                                Text("Capabilities: \(plugin.capabilities.map(\.rawValue).sorted().joined(separator: ", "))")
                                    .font(.caption)
                            }
                            if !plugin.isKnown {
                                Text("NativePass does not integrate with this extension yet.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        if plugin.id != report.plugins.last?.id {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func environmentSection(_ report: SystemReport) -> some View {
        DisclosureGroup("Environment") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(report.environmentSnapshot.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack(alignment: .top) {
                        Text(key)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 220, alignment: .leading)
                        Text(value)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func actionsSection(_ report: SystemReport) -> some View {
        GroupBox("Actions") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Open Store in Finder") {
                        NSWorkspace.shared.open(report.storePathURL)
                    }
                    Button("Copy Report") {
                        appState.clipboard.copy(report.diagnosticText, clearAfter: 0)
                    }
                    rerunDiagnosticsButton(title: "Re-run Checks")
                    if appState.isRunningFullDiagnostics {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if report.storeInitialized, let firstEntry = appState.entries.first {
                    HStack {
                        Button("Test Decrypt") {
                            Task { await testDecrypt(entry: firstEntry) }
                        }
                        if let testDecryptMessage {
                            Text(testDecryptMessage)
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                        if let testDecryptGuide {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(testDecryptGuide.title)
                                    .foregroundStyle(.orange)
                                    .font(.caption.weight(.semibold))
                                Text(testDecryptGuide.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(testDecryptGuide.steps.prefix(2)) { step in
                                    if let command = step.command {
                                        HStack {
                                            Text(command)
                                                .font(.caption.monospaced())
                                                .textSelection(.enabled)
                                            Spacer()
                                            Button("Copy") {
                                                appState.clipboard.copy(command, clearAfter: 0)
                                            }
                                            .controlSize(.small)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if appState.registry.isActive(.passwordUpdate), let firstEntry = appState.entries.first {
                    Divider()
                    Text("pass-update")
                        .font(.headline)
                    HStack {
                        Text("pass update \(firstEntry)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                        Button("Copy Command") {
                            appState.clipboard.copy("pass update \(firstEntry)", clearAfter: 0)
                        }
                    }
                }

                if !report.warnings.isEmpty {
                    Divider()
                    Text("Warnings")
                        .font(.headline)
                    ForEach(report.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func statusRow(_ title: String, _ value: String, ok: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func pluginStatusBadge(_ plugin: PassPluginInfo) -> some View {
        switch plugin.state {
        case .active:
            Text("Active")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.green.opacity(0.15))
                .clipShape(Capsule())
        case .installed:
            Text("Installed")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15))
                .clipShape(Capsule())
        case .degraded:
            Text("Degraded")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.15))
                .clipShape(Capsule())
        case .foundButInactive:
            Text("Inactive")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.red.opacity(0.15))
                .clipShape(Capsule())
        case .notFound:
            EmptyView()
        }
    }

    private func rerunDiagnosticsButton(title: String) -> some View {
        Button(title) {
            Task { await rerunDiagnostics() }
        }
        .disabled(appState.isRunningFullDiagnostics)
    }

    private func rerunDiagnostics() async {
        testDecryptMessage = nil
        testDecryptGuide = nil
        gitStatus = nil
        await appState.rerunDiagnostics()
        if appState.environment.isGitRepository {
            await loadGitStatus()
        }
    }

    private func testDecrypt(entry: String) async {
        testDecryptMessage = nil
        testDecryptGuide = nil
        do {
            _ = try await appState.showEntry(entry)
            testDecryptMessage = "Decryption succeeded for \(entry)"
        } catch {
            testDecryptGuide = DecryptFailureAnalyzer.analyze(
                error: error,
                entryName: entry,
                environment: appState.environment
            )
        }
    }
}

private extension SystemReport {
    var storePathURL: URL {
        URL(fileURLWithPath: storePath, isDirectory: true)
    }
}
