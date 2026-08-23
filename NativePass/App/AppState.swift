import AppKit
import Foundation
import Observation

@Observable
final class AppState {
    private(set) var environment: PassEnvironment
    private(set) var cli: PassCLI
    private(set) var store: PassStoreService
    let registry: CapabilityRegistry
    let inspector: SystemInspector
    let clipboard: ClipboardService
    let appLock: AppLockService
    let metadataCache = EntryMetadataCache()
    let quickAccess = QuickAccessController()
    let gitSync = GitSyncState()

    private(set) var otp: OTPService?
    private(set) var git: GitService?
    private(set) var systemReport: SystemReport?
    private(set) var entries: [String] = []
    private(set) var isBootstrapping = false
    private(set) var bootstrapStep: BootstrapStep = .starting
    private(set) var isRunningFullDiagnostics = false
    private(set) var pendingSelectEntry: String?

    private var storeWatcher: StoreFileWatcher?

    var isReady: Bool {
        environment.isPassAvailable && environment.isStoreInitialized
    }

    init() {
        let environment = PassEnvironment.detect()
        let cli = PassCLI(environment: environment)
        self.environment = environment
        self.cli = cli
        self.registry = CapabilityRegistry()
        self.inspector = SystemInspector()
        self.store = PassStoreService(cli: cli, storeDirectory: environment.storeDirectory)
        self.clipboard = ClipboardService()
        self.appLock = AppLockService()
        updateGitService()
    }

    @MainActor
    func bootstrap() async {
        isBootstrapping = true
        bootstrapStep = .starting
        defer {
            bootstrapStep = .ready
            isBootstrapping = false
        }

        bootstrapStep = .checkingPlugins
        redetectEnvironmentIfNeeded()
        quickAccess.configure(appState: self)
        registry.refreshFast(environment: environment)
        updateOTPService()
        updateGitService()

        bootstrapStep = .scanningStore
        if isReady {
            entries = store.listEntriesFast()
            startStoreWatcher()
            systemReport = inspector.buildQuickReport(
                environment: environment,
                registry: registry,
                entryCount: entries.count
            )
        } else {
            entries = []
            stopStoreWatcher()
            systemReport = inspector.buildQuickReport(
                environment: environment,
                registry: registry,
                entryCount: nil
            )
        }

        bootstrapStep = .preparingWorkspace
        // Git and full diagnostics must not block the first UI paint.
        Task { await refreshGitStatus() }
        Task { await runFullDiagnostics() }
    }

    @MainActor
    func refreshOnActivate() async {
        redetectEnvironmentIfNeeded()
        registry.refreshFast(environment: environment)
        updateOTPService()
        updateGitService()
        Task { await refreshGitStatus() }
        Task { await runFullDiagnostics() }
    }

    @MainActor
    func reloadEntries() {
        entries = store.listEntriesFast()
        Task { await refreshGitStatus() }
    }

    @MainActor
    func refreshGitStatus() async {
        await gitSync.refresh(using: git)
    }

    @MainActor
    func afterMutation(selectEntry: String? = nil) async {
        reloadEntries()
        if let selectEntry {
            pendingSelectEntry = selectEntry
        }
    }

    @MainActor
    func requestSelectEntry(_ name: String) {
        pendingSelectEntry = name
    }

    @MainActor
    func consumePendingSelectEntry() -> String? {
        defer { pendingSelectEntry = nil }
        return pendingSelectEntry
    }

    @MainActor
    func purgeSensitiveStateOnLock() {
        metadataCache.clear()
        clipboard.revertSensitiveCopy()
        quickAccess.hide()
        closeSettingsWindows()
        NotificationCenter.default.post(name: .nativePassDidLock, object: nil)
    }

    @MainActor
    func clearMetadataOnLock() {
        purgeSensitiveStateOnLock()
    }

    @MainActor
    func loadEntry(_ name: String) async throws -> PassEntry {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        return try await store.loadEntry(name)
    }

    @MainActor
    func showEntry(_ name: String) async throws -> String {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        return try await store.show(name)
    }

    @MainActor
    func saveEntry(_ name: String, content: String, force: Bool = true) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        try await store.saveEntry(name, content: content, force: force)
    }

    @MainActor
    func saveEntry(_ entry: PassEntry, force: Bool = true) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        try await store.saveEntry(entry, force: force)
    }

    @MainActor
    func removeEntry(_ name: String) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        try await store.removeEntry(name)
    }

    @MainActor
    func renameEntry(from oldName: String, to newName: String) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        try await store.renameEntry(from: oldName, to: newName)
    }

    @MainActor
    func generateEntry(
        name: String,
        length: Int = AppPreferences.defaultPasswordLength,
        noSymbols: Bool = false,
        force: Bool = true
    ) async throws -> String {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        return try await store.generateEntry(
            name: name,
            length: length,
            noSymbols: noSymbols,
            force: force
        )
    }

    @MainActor
    func closeSettingsWindowsIfNeeded() {
        closeSettingsWindows()
    }

    @MainActor
    private func closeSettingsWindows() {
        for window in NSApp.windows where isSettingsWindow(window) {
            window.orderOut(nil)
            window.close()
        }
    }

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        if window.title.localizedCaseInsensitiveContains("settings") {
            return true
        }

        let className = String(describing: type(of: window))
        if className.localizedCaseInsensitiveContains("Settings") {
            return true
        }

        // SwiftUI settings windows are often auxiliary panels with empty titles.
        if window.isKind(of: NSPanel.self), window.title.isEmpty {
            let autosaveName = window.frameAutosaveName
            if !autosaveName.isEmpty, autosaveName.localizedCaseInsensitiveContains("settings") {
                return true
            }
        }

        return window.identifier?.rawValue == "settings"
    }

    @MainActor
    func rerunDiagnostics() async {
        redetectEnvironmentIfNeeded()
        await refreshGitStatus()
        await runFullDiagnostics()
    }

    /// Re-scan pass binary / extension paths so newly installed plugins are picked up.
    @MainActor
    @discardableResult
    func redetectEnvironmentIfNeeded() -> Bool {
        let fresh = PassEnvironment.detect(storeDirectory: environment.storeDirectory)
        guard !fresh.isEquivalent(to: environment) else { return false }

        let storeChanged = fresh.storeDirectory != environment.storeDirectory
        let wasReady = isReady
        environment = fresh
        cli = PassCLI(environment: fresh)
        store = PassStoreService(cli: cli, storeDirectory: fresh.storeDirectory)

        // Also restart when readiness flips on the same path (e.g. after setup).
        if storeChanged || wasReady != isReady {
            stopStoreWatcher()
            if isReady {
                startStoreWatcher()
            }
        }

        updateGitService()
        return true
    }

    @MainActor
    private func runFullDiagnostics() async {
        isRunningFullDiagnostics = true
        defer { isRunningFullDiagnostics = false }

        redetectEnvironmentIfNeeded()
        await registry.refresh(environment: environment, cli: cli)
        updateOTPService()
        updateGitService()

        systemReport = await inspector.inspect(
            environment: environment,
            cli: cli,
            registry: registry,
            filesystemEntryCount: store.listEntriesFast().count
        )

        if isReady {
            if let cliEntries = try? await store.listEntries(), !cliEntries.isEmpty {
                entries = cliEntries
            }
        }
    }

    private func updateOTPService() {
        if registry.hasOTP {
            otp = OTPService(cli: cli)
        } else {
            otp = nil
        }
    }

    private func updateGitService() {
        if environment.isGitRepository {
            git = GitService(cli: cli)
        } else {
            git = nil
        }
    }

    @MainActor
    private func startStoreWatcher() {
        guard storeWatcher == nil else { return }
        let watcher = StoreFileWatcher(storeDirectory: environment.storeDirectory) { [weak self] in
            Task { @MainActor in
                self?.reloadEntries()
            }
        }
        watcher.start()
        storeWatcher = watcher
    }

    @MainActor
    private func stopStoreWatcher() {
        storeWatcher?.stop()
        storeWatcher = nil
    }
}