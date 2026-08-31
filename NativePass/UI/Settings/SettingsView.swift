import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var storePath: String = ""
    @State private var passwordLength: Int = AppPreferences.generatedPasswordLength
    @State private var clipboardTimeout: Double = AppPreferences.clipboardClearTimeout
    @State private var revealHideDelay: Double = AppPreferences.revealHideDelay
    @State private var importHelp: String?
    @State private var lockTimeout: AppLockService.LockTimeout = .fifteen
    @State private var securityChangeError: String?
    @State private var selectedLanguage: AppLanguage = .system
    @State private var showLanguageRestartAlert = false

    var body: some View {
        Group {
            if appState.appLock.isBlocking {
                lockedContent
            } else {
                settingsContent
            }
        }
        .frame(minWidth: 640, minHeight: 360)
        .onAppear {
            syncLocalState()
            closeIfBlocked()
        }
        .onChange(of: appState.appLock.isBlocking) { _, isBlocking in
            if isBlocking {
                closeIfBlocked()
            } else {
                syncLocalState()
            }
        }
        .alert("Authentication Required", isPresented: .init(
            get: { securityChangeError != nil },
            set: { if !$0 { securityChangeError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(securityChangeError ?? "")
        }
        .alert("Restart NativePass?", isPresented: $showLanguageRestartAlert) {
            Button("Restart Now") {
                AppLanguage.relaunchApp()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Language changes apply after restart.")
        }
    }

    private var lockedContent: some View {
        ContentUnavailableView {
            Label("NativePass is Locked", systemImage: "lock.fill")
        } description: {
            Text("Unlock NativePass to change settings.")
        }
    }

    private var settingsContent: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            quickAccessTab
                .tabItem { Label("Quick Access", systemImage: "bolt.horizontal.circle") }

            securityTab
                .tabItem { Label("Security", systemImage: "lock") }

            if appState.environment.isGitRepository {
                syncTab
                    .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
            }

            NavigationStack {
                SystemDiagnosticsView()
            }
            .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
        }
        .tabViewStyle(.tabBarOnly)
    }

    private var generalTab: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(AppLanguage.pickerCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: selectedLanguage) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    applyLanguage(newValue)
                }

                Text("System follows macOS language. Other choices override it for NativePass.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Password Store") {
                TextField("Store path", text: $storePath)
                    .onSubmit { saveStorePath() }
                Text("Default: ~/.password-store")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Apply Store Path") {
                    saveStorePath()
                }
            }

            Section("Passwords") {
                Stepper("Generated length: \(passwordLength)", value: $passwordLength, in: 8...128)
                    .onChange(of: passwordLength) { _, value in
                        AppPreferences.generatedPasswordLength = value
                    }
            }

            Section("Clipboard") {
                Stepper(
                    "Clear after \(Int(clipboardTimeout))s",
                    value: $clipboardTimeout,
                    in: 0...300,
                    step: 5
                )
                .onChange(of: clipboardTimeout) { _, value in
                    AppPreferences.clipboardClearTimeout = value
                }
            }

            Section("Reveal") {
                Stepper(
                    "Auto-hide revealed password after \(Int(revealHideDelay))s",
                    value: $revealHideDelay,
                    in: 0...120,
                    step: 5
                )
                .onChange(of: revealHideDelay) { _, value in
                    AppPreferences.revealHideDelay = value
                }
            }

            if appState.registry.isActive(.passwordImport) {
                Section("Import") {
                    Text("pass-import is available. Full import wizard is not implemented yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Show pass import --help") {
                        Task { await loadImportHelp() }
                    }
                    if let importHelp {
                        ScrollView {
                            Text(importHelp)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var quickAccessTab: some View {
        @Bindable var shortcuts = appState.shortcuts

        return Form {
            Section("Hotkey") {
                LabeledContent("Global hotkey") {
                    ShortcutRecorderControl(
                        binding: $shortcuts.quickAccess,
                        onReset: { shortcuts.resetQuickAccess() }
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var securityTab: some View {
        Form {
            Section("App Lock") {
                Toggle("Require authentication", isOn: appLockEnabledBinding)

                Picker("Lock after", selection: $lockTimeout) {
                    ForEach(AppLockService.LockTimeout.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .disabled(!appState.appLock.isEnabled)
                .onChange(of: lockTimeout) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    Task { await updateLockTimeout(newValue, revertingFrom: oldValue) }
                }

                Text("Uses Touch ID or device password to unlock the app UI. GPG decryption still uses pinentry-mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("GPG Touch ID") {
                Text("To use Touch ID when decrypting passwords, install pinentry-mac and add to ~/.gnupg/gpg-agent.conf:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("pinentry-program /opt/homebrew/bin/pinentry-mac")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appLockEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.appLock.isEnabled },
            set: { newValue in
                Task { await updateAppLockEnabled(newValue) }
            }
        )
    }

    private var syncTab: some View {
        Form {
            Section("Git Status") {
                Text("Use the sync button in the main toolbar for Pull and Push.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let gitStatus = appState.gitSync.status {
                    LabeledContent("Branch", value: gitStatus.branch ?? "—")
                    LabeledContent("Status", value: gitStatus.isClean ? String(localized: "Clean") : String(localized: "\(gitStatus.changedFilesCount) changed"))
                    if gitStatus.hasUpstream {
                        LabeledContent("Ahead", value: "\(gitStatus.aheadCount)")
                        LabeledContent("Behind", value: "\(gitStatus.behindCount)")
                    }
                } else {
                    Text("Git status unavailable.")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Status") {
                    Task { await appState.refreshGitStatus() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await appState.refreshGitStatus() }
    }

    private func syncLocalState() {
        storePath = appState.environment.storeDirectory.path
        passwordLength = AppPreferences.generatedPasswordLength
        clipboardTimeout = AppPreferences.clipboardClearTimeout
        revealHideDelay = AppPreferences.revealHideDelay
        lockTimeout = appState.appLock.timeout
        selectedLanguage = AppLanguage.preference
    }

    private func applyLanguage(_ language: AppLanguage) {
        AppLanguage.select(language)
        selectedLanguage = AppLanguage.preference
        showLanguageRestartAlert = true
    }

    private func closeIfBlocked() {
        guard appState.appLock.isBlocking else { return }
        dismissWindow(id: "settings")
        appState.closeSettingsWindowsIfNeeded()
    }

    @MainActor
    private func updateAppLockEnabled(_ newValue: Bool) async {
        guard newValue != appState.appLock.isEnabled else { return }

        if newValue {
            appState.appLock.enableLock()
            return
        }

        let success = await appState.appLock.disableLockAfterAuthentication()
        if !success {
            securityChangeError = String(localized: "Authentication failed. App Lock was not turned off.")
        }
    }

    @MainActor
    private func updateLockTimeout(_ newValue: AppLockService.LockTimeout, revertingFrom oldValue: AppLockService.LockTimeout) async {
        let success = await appState.appLock.updateTimeoutAfterAuthentication(newValue)
        if success {
            lockTimeout = appState.appLock.timeout
        } else {
            lockTimeout = oldValue
            securityChangeError = String(localized: "Authentication failed. Lock timeout was not changed.")
        }
    }

    private func saveStorePath() {
        guard !appState.appLock.isBlocking else { return }
        let url = URL(fileURLWithPath: storePath, isDirectory: true)
        PassEnvironment.saveStoreDirectory(url)
        Task { await appState.bootstrap() }
    }

    private func loadImportHelp() async {
        do {
            importHelp = try await appState.cli.runOrThrow(["import", "--help"], timeout: 10)
        } catch {
            importHelp = error.localizedDescription
        }
    }
}
