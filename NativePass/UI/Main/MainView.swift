import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var editorMode: EntryEditorMode?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var detailPaneController = DetailPaneController()
    @FocusState private var isSearchFocused: Bool

    private var categoryEntries: [String] {
        PassFolderNode.entries(
            for: appState.selectedCategory,
            from: appState.entries,
            metadataCache: appState.metadataCache
        )
    }

    private var displayedEntries: [String] {
        if appState.searchText.isEmpty {
            return categoryEntries
        }
        return appState.entries.filter { $0.localizedCaseInsensitiveContains(appState.searchText) }
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
                // Preserve a pending jump (e.g. Quick Access → main window).
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
        .sheet(item: $editorMode) { mode in
            EntryEditorSheet(mode: mode) { savedName in
                appState.selectedEntry = savedName
            }
            .environment(appState)
        }
        .onChange(of: appState.entries) { _, entries in
            pruneInvalidNavigation(using: entries)
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
        .onReceive(NotificationCenter.default.publisher(for: .nativePassCopyPassword)) { _ in
            guard !appState.appLock.isBlocking else { return }
            copySelectedPassword()
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
        }
    }

    func focusSearch() {
        isSearchFocused = true
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
}
