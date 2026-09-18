import AppKit
import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var editorMode: EntryEditorMode?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var detailPaneController = DetailPaneController()
    /// Sole source of truth for region keyboard navigation (Tab / ⌘1–2 / ⌘F).
    @State private var activePane: MainPaneFocus = .list
    @FocusState private var isSearchFocused: Bool

    private var categoryEntries: [String] {
        PassFolderNode.entries(
            for: appState.selectedCategory,
            from: appState.entries,
            metadataCache: appState.metadataCache
        )
    }

    private var displayedEntries: [String] {
        let query = appState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return categoryEntries
        }
        return EntrySearch.ranked(appState.entries, query: query)
    }

    private var listEntries: [String] {
        let query = appState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return appState.entrySortOrder.sorted(displayedEntries)
        }
        return displayedEntries
    }

    private var suggestedPath: String? {
        appState.selectedCategory.folderPath
    }

    private var listEmptyState: (title: String, description: String) {
        switch appState.selectedCategory {
        case .verificationCodes:
            return (
                String(localized: "No Verification Codes"),
                String(localized: "Entries with OTP secrets appear here after you view them.")
            )
        case .folder(let path):
            return (
                String(localized: "No Passwords"),
                String(localized: "No entries in \"\(path)\".")
            )
        case .all:
            return (
                String(localized: "No Passwords"),
                String(localized: "Create a new entry with ⌘N or run pass insert in Terminal.")
            )
        }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                folders: PassFolderNode.buildFolderTree(from: appState.entries),
                showVerificationCodes: appState.registry.hasOTP,
                selectedCategory: $appState.selectedCategory,
                columnVisibility: $columnVisibility
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
            .onChange(of: appState.selectedCategory) { _, _ in
                if appState.pendingSelectEntry != nil { return }
                appState.selectedEntry = nil
                detailPaneController.reset()
            }
        } content: {
            EntryListView(
                entries: displayedEntries,
                folderTitle: appState.selectedCategory.listTitle,
                emptyTitle: listEmptyState.title,
                emptyDescription: listEmptyState.description,
                selectedEntry: $appState.selectedEntry,
                searchText: $appState.searchText,
                sortOrder: $appState.entrySortOrder,
                onNewEntry: {
                    guard !appState.appLock.isBlocking else { return }
                    editorMode = .create(suggestedPath: suggestedPath)
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } detail: {
            Group {
                if let selectedEntry = appState.selectedEntry {
                    EntryDetailView(
                        entryName: selectedEntry,
                        detailController: detailPaneController
                    )
                } else {
                    PassEmptyState(
                        title: String(localized: "No Entry Selected"),
                        systemImage: "key",
                        description: String(localized: "Select a password entry to view details.")
                    )
                    .onAppear { detailPaneController.reset() }
                }
            }
            .navigationTitle("")
            .searchable(text: $appState.searchText, prompt: "Search")
            .searchFocused($isSearchFocused)
            .toolbar {
                DetailPaneToolbarContent(controller: detailPaneController)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background {
            LocalKeyboardMonitor { event, window in
                handleLocalKeyEvent(event, window: window)
            }
        }
        .onKeyPress(.escape) {
            handleEscape()
        }
        .onChange(of: isSearchFocused) { _, focused in
            if focused {
                activePane = .search
            }
        }
        .sheet(item: $editorMode) { mode in
            EntryEditorSheet(mode: mode) { savedName in
                appState.selectedEntry = savedName
            }
            .environment(appState)
        }
        .onChange(of: appState.entries) { _, entries in
            pruneInvalidNavigation(using: entries)
        }
        .onAppear {
            applyPendingSelectEntryIfNeeded()
        }
        .onChange(of: appState.pendingSelectEntry) { _, newValue in
            if let newValue {
                appState.selectedEntry = newValue
                _ = appState.consumePendingSelectEntry()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassDidLock)) { _ in
            editorMode = nil
            detailPaneController.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassNewEntry)) { _ in
            guard !appState.appLock.isBlocking else { return }
            showNewEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassFocusSearch)) { _ in
            guard !appState.appLock.isBlocking else { return }
            focusSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassFocusPane)) { notification in
            guard !appState.appLock.isBlocking else { return }
            guard let pane = MainPaneFocusNotification.pane(from: notification) else { return }
            focusPane(pane)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassCyclePane)) { notification in
            guard !appState.appLock.isBlocking else { return }
            cyclePane(backward: MainPaneFocusNotification.isBackward(from: notification))
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassCopyPassword)) { _ in
            guard !appState.appLock.isBlocking else { return }
            copySelectedPassword()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassCopyRawEntry)) { _ in
            guard !appState.appLock.isBlocking else { return }
            copySelectedRawEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassGitPull)) { _ in
            guard !appState.appLock.isBlocking else { return }
            Task {
                await appState.gitSync.pull(using: appState.git)
                await appState.reloadEntries()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativePassGitPush)) { _ in
            guard !appState.appLock.isBlocking else { return }
            Task { await appState.gitSync.push(using: appState.git) }
        }
        .clipboardToast(message: appState.clipboard.lastCopyMessage) {
            appState.clipboard.dismissMessage()
        }
        .overlay(alignment: .bottom) {
            if let message = appState.gitSync.lastMessage {
                Text(message)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, appState.clipboard.lastCopyMessage != nil ? 40 : 12)
                    .onTapGesture { appState.gitSync.clearMessage() }
            }
        }
        .onAppear {
            pruneInvalidNavigation(using: appState.entries)
            activePane = .list
            DispatchQueue.main.async {
                focusPane(.list)
            }
        }
    }

    func focusSearch() {
        activePane = .search
        isSearchFocused = true
    }

    func focusPane(_ pane: MainPaneFocus, window: NSWindow? = nil) {
        activePane = pane

        if pane == .search {
            isSearchFocused = true
            return
        }

        isSearchFocused = false
        let targetWindow = AppKitFocusHelper.preferredWindow(fallback: window)
        AppKitFocusHelper.focusMainPane(pane, in: targetWindow)
        DispatchQueue.main.async {
            activePane = pane
            isSearchFocused = false
            AppKitFocusHelper.focusMainPane(
                pane,
                in: AppKitFocusHelper.preferredWindow(fallback: targetWindow)
            )
        }
    }

    func cyclePane(backward: Bool) {
        // While editing an entry, keep system Tab for form fields.
        if detailPaneController.isEditing {
            return
        }
        if isSearchFocused {
            activePane = .search
        }
        focusPane(nextPane(from: activePane, backward: backward))
    }

    func showNewEntry() {
        guard !appState.appLock.isBlocking else { return }
        editorMode = .create(suggestedPath: suggestedPath)
    }

    func copySelectedPassword() {
        guard !appState.appLock.isBlocking else { return }
        guard let selectedEntry = appState.selectedEntry else {
            appState.clipboard.showMessage(String(localized: "Select an entry to copy its password."))
            return
        }
        Task {
            if let entry = try? await appState.loadEntry(selectedEntry) {
                appState.metadataCache.update(from: entry)
                appState.clipboard.copy(entry.password, showToast: false)
                NotificationCenter.default.post(
                    name: .nativePassPasswordCopiedInline,
                    object: nil,
                    userInfo: ["scope": selectedEntry]
                )
            }
        }
    }

    func copySelectedRawEntry() {
        guard !appState.appLock.isBlocking else { return }
        guard let selectedEntry = appState.selectedEntry else {
            appState.clipboard.showMessage(String(localized: "Select an entry to copy."))
            return
        }
        Task {
            if let entry = try? await appState.loadEntry(selectedEntry) {
                appState.metadataCache.update(from: entry)
                appState.clipboard.copy(entry.rawContent)
            }
        }
    }

    private func handleEscape() -> KeyPress.Result {
        if detailPaneController.isEditing {
            detailPaneController.cancel()
            return .handled
        }

        if isSearchFocused || activePane == .search {
            if !appState.searchText.isEmpty {
                appState.searchText = ""
            }
            focusPane(.list)
            return .handled
        }

        return .ignored
    }

    private func handleLocalKeyEvent(_ event: NSEvent, window: NSWindow?) -> NSEvent? {
        if editorMode != nil { return event }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // ⌘1 / ⌘2
        if modifiers == .command, !detailPaneController.isEditing {
            switch event.keyCode {
            case KeyboardKeyCode.one:
                DispatchQueue.main.async { focusPane(.sidebar, window: window) }
                return nil
            case KeyboardKeyCode.two:
                DispatchQueue.main.async { focusPane(.list, window: window) }
                return nil
            default:
                break
            }
        }

        if event.keyCode == KeyboardKeyCode.tab {
            let nonShift = modifiers.subtracting(.shift)
            guard nonShift.isEmpty else { return event }
            // While editing, let Tab move between form controls.
            if detailPaneController.isEditing {
                return event
            }
            let backward = modifiers.contains(.shift)
            DispatchQueue.main.async {
                MainPaneFocusNotification.postCycle(backward: backward)
            }
            return nil
        }

        let searchActive = isSearchFocused || activePane == .search
        guard searchActive else { return event }
        guard modifiers.isEmpty else { return event }
        guard !detailPaneController.isEditing else { return event }

        let delta: Int
        switch event.keyCode {
        case KeyboardKeyCode.downArrow: delta = 1
        case KeyboardKeyCode.upArrow: delta = -1
        default: return event
        }

        var selection = appState.selectedEntry
        ListSelectionMovement.move(selection: &selection, in: listEntries, delta: delta)
        appState.selectedEntry = selection
        return nil
    }

    private func nextPane(from current: MainPaneFocus, backward: Bool) -> MainPaneFocus {
        let order: [MainPaneFocus] = [.sidebar, .list, .search]
        guard let index = order.firstIndex(of: current) else { return .list }
        let offset = backward ? -1 : 1
        let nextIndex = (index + offset + order.count) % order.count
        return order[nextIndex]
    }

    private func pruneInvalidNavigation(using entries: [String]) {
        if let selectedEntry = appState.selectedEntry, !entries.contains(selectedEntry) {
            appState.selectedEntry = nil
            detailPaneController.reset()
        }

        if case .folder(let path) = appState.selectedCategory {
            let folderStillExists = entries.contains { entry in
                entry == path || entry.hasPrefix(path + "/")
            }
            if !folderStillExists {
                appState.selectedCategory = .all
                appState.selectedEntry = nil
                detailPaneController.reset()
            }
        }
    }

    private func applyPendingSelectEntryIfNeeded() {
        guard let pending = appState.consumePendingSelectEntry() else { return }
        appState.selectedEntry = pending
    }
}
