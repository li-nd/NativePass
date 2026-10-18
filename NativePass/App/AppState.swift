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
    let shortcuts = ShortcutStore()
    let gitSync = GitSyncState()

    private(set) var otp: OTPService?
    private(set) var git: GitService?
    private(set) var systemReport: SystemReport?
    private(set) var entries: [String] = []
    private(set) var encryptionMap: StoreEncryptionMap = .empty
    private(set) var recipientLabels: [String: String] = [:]
    private(set) var isBootstrapping = false
    private(set) var bootstrapStep: BootstrapStep = .starting
    private(set) var isRunningFullDiagnostics = false
    private(set) var pendingSelectEntry: String?

    /// Navigation state survives App Lock (MainView is torn down while locked).
    var selectedCategory: SidebarSelection = .all
    var selectedEntry: String?
    var searchText = ""
    var entrySortOrder: EntrySortOrder = .byName
    /// True while the detail pane is editing an entry (menus / shortcuts).
    var isEditingEntry = false
    /// Selected entry has at least two Git revisions (History is useful).
    private(set) var selectedEntryHasHistory = false

    /// When set, Settings opens on this tab and then clears the value.
    var pendingSettingsTab: SettingsTab?

    /// Known store paths from the registry (for sidebar / settings).
    var storePaths: [URL] { StoreRegistry.paths }

    var activeStoreURL: URL { environment.storeDirectory }

    private var storeWatcher: StoreFileWatcher?

    /// SwiftUI `openWindow(id:)` callback — kept so main window can be recreated after close.
    @ObservationIgnored
    private var openMainWindowHandler: (@MainActor () -> Void)?

    var isReady: Bool {
        environment.isPassAvailable && environment.isStoreInitialized
    }

    init() {
        _ = StoreRegistry.ensureDefaultFallback()
        let environment = PassEnvironment.detect(storeDirectory: StoreRegistry.activeURL)
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
        quickAccess.configure(appState: self, shortcutStore: shortcuts)
        registry.refreshFast(environment: environment)
        updateOTPService()
        updateGitService()

        bootstrapStep = .scanningStore
        if isReady {
            entries = store.listEntriesFast()
            refreshEncryptionMap()
            startStoreWatcher()
            systemReport = inspector.buildQuickReport(
                environment: environment,
                registry: registry,
                entryCount: entries.count
            )
        } else {
            entries = []
            refreshEncryptionMap()
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
        refreshEncryptionMap()
        Task { await refreshGitStatus() }
    }

    @MainActor
    func refreshEncryptionMap() {
        encryptionMap = StoreEncryptionMap.scan(storeDirectory: environment.storeDirectory)
        let ids = Set(encryptionMap.rootIDs + encryptionMap.localPolicies.values.flatMap { $0 })
        if !ids.isEmpty {
            recipientLabels = GPGKeyListing.displayLabels(
                for: Array(ids),
                gpgBinary: environment.gpgBinary,
                environment: environment.processEnvironment()
            )
        } else {
            recipientLabels = [:]
        }
    }

    func displayLabel(forGPGID id: String) -> String {
        recipientLabels[id] ?? id
    }

    func displayLabels(forGPGIDs ids: [String]) -> String {
        ids.map { displayLabel(forGPGID: $0) }.joined(separator: ", ")
    }

    @MainActor
    func switchStore(to url: URL) async {
        guard !appLock.isBlocking else { return }
        let normalized = StoreRegistry.normalize(url)
        StoreRegistry.setActive(normalized)
        resetNavigationState()
        applyStoreDirectory(normalized)
        await bootstrap()
    }

    @MainActor
    func switchToStore(atIndex index: Int) async {
        let paths = storePaths
        guard paths.indices.contains(index) else { return }
        await switchStore(to: paths[index])
    }

    @MainActor
    func switchToAdjacentStore(offset: Int) async {
        let paths = storePaths
        guard paths.count >= 2 else { return }
        let current = activeStoreURL
        guard let currentIndex = paths.firstIndex(where: { StoreRegistry.samePath($0, current) }) else {
            await switchStore(to: paths[0])
            return
        }
        let count = paths.count
        let next = (currentIndex + offset % count + count) % count
        await switchStore(to: paths[next])
    }

    @MainActor
    func openSettings(tab: SettingsTab? = nil) {
        pendingSettingsTab = tab
    }

    @MainActor
    func addExistingStore(_ url: URL) async {
        let normalized = StoreRegistry.add(url)
        await switchStore(to: normalized)
    }

    @MainActor
    func removeStoreFromList(_ url: URL, deleteFromDisk: Bool = false) async throws {
        let normalized = StoreRegistry.normalize(url)
        let wasActive = StoreRegistry.samePath(normalized, environment.storeDirectory)
        let nextActive = StoreRegistry.remove(normalized)

        if wasActive || !StoreRegistry.samePath(nextActive, environment.storeDirectory) {
            await switchStore(to: nextActive)
        }

        guard deleteFromDisk else { return }

        try Self.deleteStoreDirectoryIfSafe(normalized)
    }

    /// Removes a registered store directory from disk after safety checks.
    private static func deleteStoreDirectoryIfSafe(_ url: URL) throws {
        let normalized = StoreRegistry.normalize(url)
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let path = normalized.path

        guard path != "/", path != home.path else {
            throw PassError.parseFailed(String(localized: "Refusing to delete a protected path."))
        }
        // Never delete the home directory or anything above the user's home via relative tricks.
        guard path.hasPrefix(home.path + "/") else {
            throw PassError.parseFailed(String(localized: "Refusing to delete a path outside your home folder."))
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        try FileManager.default.removeItem(at: normalized)
    }

    /// Creates a new store at `url` with the given keys, optionally runs `pass git init`, then activates it.
    @MainActor
    func createStore(
        at url: URL,
        gpgIDs: [String],
        initializeGit: Bool
    ) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        let normalized = StoreRegistry.normalize(url)
        try FileManager.default.createDirectory(at: normalized, withIntermediateDirectories: true)

        let tempEnv = PassEnvironment.detect(storeDirectory: normalized)
        let tempCLI = PassCLI(environment: tempEnv)
        try await tempCLI.initStore(gpgIDs: gpgIDs)
        if initializeGit {
            try await tempCLI.gitInit()
        }

        StoreRegistry.add(normalized)
        await switchStore(to: normalized)
    }

    @MainActor
    func changeEncryptionKeys(gpgIDs: [String], folderPath: String?) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        let path = folderPath.flatMap { $0.isEmpty ? nil : $0 }
        try await cli.initStore(gpgIDs: gpgIDs, path: path)
        redetectEnvironmentIfNeeded()
        reloadEntries()
        await refreshGitStatus()
        await runFullDiagnostics()
    }

    @MainActor
    private func resetNavigationState() {
        selectedCategory = .all
        selectedEntry = nil
        searchText = ""
        pendingSelectEntry = nil
        isEditingEntry = false
        selectedEntryHasHistory = false
        metadataCache.clear()
    }

    @MainActor
    private func applyStoreDirectory(_ url: URL) {
        stopStoreWatcher()
        let fresh = PassEnvironment.detect(storeDirectory: url)
        environment = fresh
        cli = PassCLI(environment: fresh)
        store = PassStoreService(cli: cli, storeDirectory: fresh.storeDirectory)
        updateGitService()
        updateOTPService()
        encryptionMap = .empty
        recipientLabels = [:]
        entries = []
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
    func setSelectedEntryHasHistory(_ value: Bool) {
        selectedEntryHasHistory = value
    }

    @MainActor
    func requestSelectEntry(_ name: String) {
        selectedCategory = .all
        searchText = ""
        selectedEntry = name
        pendingSelectEntry = name
    }

    @MainActor
    func consumePendingSelectEntry() -> String? {
        defer { pendingSelectEntry = nil }
        return pendingSelectEntry
    }

    @MainActor
    func bindOpenMainWindow(_ handler: @escaping @MainActor () -> Void) {
        openMainWindowHandler = handler
    }

    /// Bring the main window forward, deminiaturize, or recreate it if it was closed.
    @MainActor
    func revealMainWindow() {
        let candidates = Self.mainWindowCandidates()
        if let window = Self.pickMainWindow(from: candidates) {
            Self.presentMainWindow(window)
            Self.closeDuplicateMainWindows(keeping: window, from: candidates)
            return
        }

        openMainWindowHandler?()
        DockVisibility.prepareForShowingWindow()
        NSApp.activate(ignoringOtherApps: true)

        Task { @MainActor in
            for delay in [16, 50, 100, 250, 500] as [UInt64] {
                try? await Task.sleep(for: .milliseconds(delay))
                let candidates = Self.mainWindowCandidates()
                if let window = Self.pickMainWindow(from: candidates) {
                    Self.presentMainWindow(window)
                    Self.closeDuplicateMainWindows(keeping: window, from: candidates)
                    return
                }
            }
        }
    }

    @MainActor
    private static func presentMainWindow(_ window: NSWindow) {
        DockVisibility.prepareForShowingWindow()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private static func mainWindowCandidates() -> [NSWindow] {
        NSApp.windows.filter(isMainWindowCandidate)
    }

    @MainActor
    private static func pickMainWindow(from candidates: [NSWindow]) -> NSWindow? {
        candidates.first(where: { $0.isVisible && !$0.isMiniaturized })
            ?? candidates.first(where: \.isMiniaturized)
            ?? candidates.first
    }

    @MainActor
    private static func closeDuplicateMainWindows(keeping keep: NSWindow, from candidates: [NSWindow]) {
        for window in candidates where window !== keep {
            window.close()
        }
    }

    /// Miniaturized windows often report `canBecomeMain == false`, so include them explicitly.
    private static func isMainWindowCandidate(_ window: NSWindow) -> Bool {
        if window is NSPanel { return false }
        if isMainWindowExcluded(window) { return false }
        if window.identifier?.rawValue == AppWindowID.main { return true }
        return window.canBecomeMain || window.isMiniaturized
    }

    private static func isMainWindowExcluded(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == AppWindowID.settings {
            return true
        }
        if window.title.localizedCaseInsensitiveContains("settings") {
            return true
        }
        let className = String(describing: type(of: window))
        return className.localizedCaseInsensitiveContains("Settings")
    }

    @MainActor
    func purgeSensitiveStateOnLock() {
        isEditingEntry = false
        selectedEntryHasHistory = false
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
    func listEntryRevisions(_ name: String) async throws -> [EntryRevision] {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        guard let git else {
            throw PassError.parseFailed(String(localized: "Password store is not a Git repository."))
        }
        return try await git.revisions(forEntry: name)
    }

    @MainActor
    func loadEntry(_ name: String, at revision: EntryRevision) async throws -> PassEntry {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        return try await store.loadEntry(name, at: revision)
    }

    @MainActor
    func restoreEntry(_ name: String, from revision: EntryRevision) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        let historical = try await store.loadEntry(name, at: revision)
        try await store.saveEntry(name, content: historical.rawContent, force: true)
        await afterMutation(selectEntry: name)
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
    func removeFolder(_ path: String) async throws {
        guard !appLock.isBlocking else { throw AppLockError.locked }
        try await store.removeFolder(path)
        if case .folder(let selected) = selectedCategory,
           selected == path || selected.hasPrefix(path + "/") {
            selectedCategory = .all
        }
        if let entry = selectedEntry,
           entry == path || entry.hasPrefix(path + "/") {
            selectedEntry = nil
        }
        await afterMutation()
    }

    func entries(underFolder path: String) -> [String] {
        store.entries(underFolder: path)
    }

    func entryModificationDate(for name: String) -> Date? {
        store.modificationDate(forEntry: name)
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

        return window.identifier?.rawValue == AppWindowID.settings
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
        let active = StoreRegistry.ensureDefaultFallback()
        let fresh = PassEnvironment.detect(storeDirectory: active)
        guard !fresh.isEquivalent(to: environment) else {
            // Still refresh encryption map when path unchanged but files may have changed.
            return false
        }

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