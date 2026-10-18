import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var passwordLength: Int = AppPreferences.generatedPasswordLength
    @State private var clipboardTimeout: Double = AppPreferences.clipboardClearTimeout
    @State private var revealHideDelay: Double = AppPreferences.revealHideDelay
    @State private var importHelp: String?
    @State private var lockTimeout: AppLockService.LockTimeout = .fifteen
    @State private var securityChangeError: String?
    @State private var selectedLanguage: AppLanguage = AppLanguage.preference
    @State private var showLanguageRestartAlert = false
    @State private var autoTypeEnabled = AppPreferences.autoTypeEnabled
    @State private var quickAccessPrimaryAction = AppPreferences.quickAccessPrimaryAction
    @State private var autoTypeDelay = AppPreferences.autoTypeDelayMilliseconds
    @State private var showFieldPreviews = AppPreferences.showQuickAccessFieldPreviews
    @State private var hideFromDock = AppPreferences.hideFromDock
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled
    @State private var launchAtLoginMessage: String?
    @State private var accessibilityTrusted = AutoTypeService.isTrusted()
    @State private var selectedStorePath: String?
    @State private var storeSetupMode: StoreKeySetupMode?
    @State private var storeActionError: String?
    @State private var storePendingRemoval: URL?
    @State private var showRemoveStoreConfirm = false
    @State private var alsoDeleteStoreFiles = false
    @State private var selectedSettingsTab: SettingsTab = .general

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
            applyPendingSettingsTab()
            closeIfBlocked()
        }
        .onChange(of: appState.pendingSettingsTab) { _, _ in
            applyPendingSettingsTab()
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
        TabView(selection: $selectedSettingsTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            storeTab
                .tabItem { Label("Store", systemImage: "folder") }
                .tag(SettingsTab.store)

            quickAccessTab
                .tabItem { Label("Quick Access", systemImage: "bolt.horizontal.circle") }
                .tag(SettingsTab.quickAccess)

            securityTab
                .tabItem { Label("Security", systemImage: "lock") }
                .tag(SettingsTab.security)

            if appState.environment.isGitRepository {
                syncTab
                    .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
                    .tag(SettingsTab.sync)
            }

            NavigationStack {
                SystemDiagnosticsView()
            }
            .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
            .tag(SettingsTab.diagnostics)
        }
        .tabViewStyle(.tabBarOnly)
        .sheet(item: $storeSetupMode) { mode in
            NavigationStack {
                StoreKeySetupSheet(mode: mode) {
                    syncLocalState()
                }
            }
            .environment(appState)
        }
        .sheet(isPresented: $showRemoveStoreConfirm, onDismiss: {
            storePendingRemoval = nil
            alsoDeleteStoreFiles = false
        }) {
            if let storePendingRemoval {
                RemoveStoreConfirmSheet(
                    storeURL: storePendingRemoval,
                    alsoDeleteFiles: $alsoDeleteStoreFiles,
                    onCancel: {
                        showRemoveStoreConfirm = false
                    },
                    onConfirm: { deleteFromDisk in
                        Task {
                            do {
                                try await appState.removeStoreFromList(
                                    storePendingRemoval,
                                    deleteFromDisk: deleteFromDisk
                                )
                                storeActionError = nil
                                showRemoveStoreConfirm = false
                                syncLocalState()
                            } catch {
                                storeActionError = error.localizedDescription
                                showRemoveStoreConfirm = false
                            }
                        }
                    }
                )
            }
        }
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

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        applyLaunchAtLogin(enabled)
                    }

                Toggle("Hide from Dock", isOn: $hideFromDock)
                    .onChange(of: hideFromDock) { _, hide in
                        AppPreferences.hideFromDock = hide
                        DockVisibility.apply(hide: hide)
                    }

                if let launchAtLoginMessage {
                    Text(launchAtLoginMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if LaunchAtLoginService.requiresApproval {
                    Button("Open Login Items Settings…") {
                        LaunchAtLoginService.openLoginItemsSettings()
                    }
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("When hidden from the Dock, use the menu bar icon or the Quick Access hotkey to open NativePass.")
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
        .onAppear {
            refreshLaunchAtLoginState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLaunchAtLoginState()
        }
    }

    private var storeTab: some View {
        Form {
            Section {
                ForEach(appState.storePaths, id: \.path) { url in
                    storeRow(for: url)
                }

                HStack(spacing: 8) {
                    Button {
                        addExistingStore()
                    } label: {
                        Label("Add Existing…", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        storeSetupMode = .create
                    } label: {
                        Label("Create Store…", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } header: {
                Text("Stores")
            } footer: {
                Text("The active store is used for browsing and editing. You can also switch from the sidebar.")
            }

            Section {
                if !appState.environment.isStoreInitialized {
                    Label("Active store is not initialized.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else if appState.encryptionMap.rootIDs.isEmpty {
                    Text("No GPG recipients in .gpg-id.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.encryptionMap.rootIDs, id: \.self) { id in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.displayLabel(forGPGID: id))
                                    .font(.body)
                                Text(id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }

                Button {
                    storeSetupMode = .changeRoot
                } label: {
                    Label("Change Encryption Keys…", systemImage: "lock.rotation")
                }
                .disabled(!appState.environment.isStoreInitialized)
            } header: {
                Text("Encryption")
            } footer: {
                Text("Recipients for \(StoreRegistry.displayPath(for: appState.activeStoreURL)). Changing keys re-encrypts the whole store.")
            }

            if let storeActionError {
                Section {
                    Text(storeActionError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedStorePath = appState.activeStoreURL.path
        }
    }

    @ViewBuilder
    private func storeRow(for url: URL) -> some View {
        let isActive = StoreRegistry.samePath(url, appState.activeStoreURL)
        let isSelected = selectedStorePath == url.path
        let canRemove = appState.storePaths.count > 1

        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: isActive ? "folder.fill" : "folder")
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(StoreRegistry.shortDisplayName(for: url))
                        .font(.body.weight(isActive ? .semibold : .regular))
                    if isActive {
                        Text("Active")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text(StoreRegistry.displayPath(for: url))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(url.path)
            }

            Spacer(minLength: 8)

            if !isActive {
                Button("Use") {
                    selectedStorePath = url.path
                    Task { await appState.switchStore(to: url) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                selectedStorePath = url.path
                alsoDeleteStoreFiles = false
                storePendingRemoval = url
                showRemoveStoreConfirm = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(canRemove ? .red : .secondary)
            .disabled(!canRemove)
            .help(
                canRemove
                    ? String(localized: "Remove \(StoreRegistry.displayPath(for: url)) from the list")
                    : String(localized: "Keep at least one store in the list")
            )
            .accessibilityLabel(
                String(localized: "Remove \(StoreRegistry.shortDisplayName(for: url)) from list")
            )
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedStorePath = url.path
        }
        .listRowBackground(
            isSelected ? Color.accentColor.opacity(0.08) : Color.clear
        )
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

            Section {
                Toggle("Enable Auto-Type", isOn: $autoTypeEnabled)
                    .onChange(of: autoTypeEnabled) { _, value in
                        AppPreferences.autoTypeEnabled = value
                        if value, !AutoTypeService.isTrusted() {
                            _ = AutoTypeService.isTrusted(prompt: true)
                            accessibilityTrusted = AutoTypeService.isTrusted()
                        }
                    }

                Picker("Return key action", selection: $quickAccessPrimaryAction) {
                    ForEach(QuickAccessPrimaryAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                .disabled(!autoTypeEnabled)
                .onChange(of: quickAccessPrimaryAction) { _, value in
                    AppPreferences.quickAccessPrimaryAction = value
                }

                LabeledContent("Delay before typing") {
                    HStack(spacing: 8) {
                        TextField(
                            "Delay",
                            value: $autoTypeDelay,
                            format: .number
                        )
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .textFieldStyle(.roundedBorder)

                        Text("ms")
                            .foregroundStyle(.secondary)

                        Stepper(
                            "Delay before typing",
                            value: $autoTypeDelay,
                            in: 0...1_000,
                            step: 50
                        )
                        .labelsHidden()
                    }
                }
                .disabled(!autoTypeEnabled)
                .onChange(of: autoTypeDelay) { _, value in
                    let clamped = min(max(value, 0), 1_000)
                    if clamped != value {
                        autoTypeDelay = clamped
                        return
                    }
                    AppPreferences.autoTypeDelayMilliseconds = clamped
                }
            } header: {
                Text("Auto-Type")
            } footer: {
                Text("When enabled, Quick Access can type the password into the app that was focused before the popup opened.")
            }

            Section {
                Toggle("Show field value previews", isOn: $showFieldPreviews)
                    .onChange(of: showFieldPreviews) { _, value in
                        AppPreferences.showQuickAccessFieldPreviews = value
                    }
            } header: {
                Text("Field Picker")
            } footer: {
                Text("When enabled, ⌥⌘↵ shows a short preview of each field value (including a live OTP code).")
            }

            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: accessibilityTrusted ? "checkmark.seal.fill" : "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)
                        .frame(width: 28, alignment: .center)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(accessibilityTrusted
                             ? String(localized: "Permission granted")
                             : String(localized: "Permission needed"))
                            .font(.body.weight(.semibold))

                        Text(accessibilityTrusted
                             ? String(localized: "NativePass may send keystrokes for Auto-Type.")
                             : String(localized: "Add NativePass in Privacy & Security → Accessibility."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text(accessibilityTrusted
                         ? String(localized: "Allowed")
                         : String(localized: "Required"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (accessibilityTrusted ? Color.green : Color.orange).opacity(0.18),
                            in: Capsule()
                        )
                        .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)
                }
                .padding(.vertical, 2)

                HStack(spacing: 10) {
                    Button {
                        AutoTypeService.openAccessibilitySettings()
                    } label: {
                        Label("System Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        accessibilityTrusted = AutoTypeService.isTrusted(prompt: false)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.regular)
                }
            } header: {
                Text("Accessibility")
            } footer: {
                Text("macOS requires Accessibility access before Auto-Type can work.")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            accessibilityTrusted = AutoTypeService.isTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = AutoTypeService.isTrusted()
        }
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
                    if !gitStatus.changedFiles.isEmpty {
                        GitChangedFilesList(files: gitStatus.changedFiles)
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
        selectedStorePath = appState.activeStoreURL.path
        passwordLength = AppPreferences.generatedPasswordLength
        clipboardTimeout = AppPreferences.clipboardClearTimeout
        revealHideDelay = AppPreferences.revealHideDelay
        lockTimeout = appState.appLock.timeout
        selectedLanguage = AppLanguage.preference
        autoTypeEnabled = AppPreferences.autoTypeEnabled
        quickAccessPrimaryAction = AppPreferences.quickAccessPrimaryAction
        autoTypeDelay = AppPreferences.autoTypeDelayMilliseconds
        showFieldPreviews = AppPreferences.showQuickAccessFieldPreviews
        hideFromDock = AppPreferences.hideFromDock
        refreshLaunchAtLoginState()
        accessibilityTrusted = AutoTypeService.isTrusted()
    }

    private func applyPendingSettingsTab() {
        guard let tab = appState.pendingSettingsTab else { return }
        if tab == .sync, !appState.environment.isGitRepository {
            selectedSettingsTab = .general
        } else {
            selectedSettingsTab = tab
        }
        appState.pendingSettingsTab = nil
    }

    private func refreshLaunchAtLoginState() {
        let pendingApproval = LaunchAtLoginService.requiresApproval
        launchAtLogin = LaunchAtLoginService.isEnabled || pendingApproval
        if pendingApproval {
            launchAtLoginMessage = String(
                localized: "macOS needs approval before NativePass can open at login."
            )
        } else {
            launchAtLoginMessage = nil
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            refreshLaunchAtLoginState()
        } catch {
            refreshLaunchAtLoginState()
            launchAtLoginMessage = error.localizedDescription
        }
    }

    private func applyLanguage(_ language: AppLanguage) {
        guard language != AppLanguage.preference else { return }
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
            syncLocalState()
        }
    }

    private func loadImportHelp() async {
        do {
            importHelp = try await appState.cli.runOrThrow(["import", "--help"], timeout: 10)
        } catch {
            importHelp = error.localizedDescription
        }
    }
}

private struct RemoveStoreConfirmSheet: View {
    let storeURL: URL
    @Binding var alsoDeleteFiles: Bool
    var onCancel: () -> Void
    var onConfirm: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remove \(StoreRegistry.shortDisplayName(for: storeURL))?")
                .font(.headline)

            Text(StoreRegistry.displayPath(for: storeURL))
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text("This removes the store from NativePass. The folder stays on disk unless you choose otherwise.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Toggle(isOn: $alsoDeleteFiles) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Also delete files from disk")
                    Text("Permanently deletes this folder and all passwords inside it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            if alsoDeleteFiles {
                Label(
                    "This cannot be undone.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(alsoDeleteFiles ? "Remove and Delete Files" : "Remove from List", role: .destructive) {
                    onConfirm(alsoDeleteFiles)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
