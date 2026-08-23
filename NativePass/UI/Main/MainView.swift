import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCategory: SidebarSelection = .all
    @State private var selectedEntry: String?
    @State private var searchText = ""
    @State private var sortOrder: EntrySortOrder = .byName
    @State private var editorMode: EntryEditorMode?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var detailPaneController = DetailPaneController()
    @FocusState private var isSearchFocused: Bool

    private var categoryEntries: [String] {
        PassFolderNode.entries(
            for: selectedCategory,
            from: appState.entries,
            metadataCache: appState.metadataCache
        )
    }

    private var displayedEntries: [String] {
        if searchText.isEmpty {
            return categoryEntries
        }
        return appState.entries.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var suggestedPath: String? {
        selectedCategory.folderPath
    }

    private var listEmptyState: (title: String, description: String) {
        switch selectedCategory {
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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                folders: PassFolderNode.buildFolderTree(from: appState.entries),
                showVerificationCodes: appState.registry.hasOTP,
                selectedCategory: $selectedCategory,
                columnVisibility: $columnVisibility
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
            .onChange(of: selectedCategory) { _, _ in
                selectedEntry = nil
                detailPaneController.reset()
            }
        } content: {
            EntryListView(
                entries: displayedEntries,
                folderTitle: selectedCategory.listTitle,
                emptyTitle: listEmptyState.title,
                emptyDescription: listEmptyState.description,
                selectedEntry: $selectedEntry,
                searchText: $searchText,
                sortOrder: $sortOrder,
                onNewEntry: {
                    guard !appState.appLock.isBlocking else { return }
                    editorMode = .create(suggestedPath: suggestedPath)
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } detail: {
            Group {
                if let selectedEntry {
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
            .searchable(text: $searchText, prompt: "Search")
            .searchFocused($isSearchFocused)
            .toolbar {
                DetailPaneToolbarContent(controller: detailPaneController)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $editorMode) { mode in
            EntryEditorSheet(mode: mode) { savedName in
                selectedEntry = savedName
            }
            .environment(appState)
        }
        .onChange(of: appState.entries) { _, entries in
            if let selectedEntry, !entries.contains(selectedEntry) {
                self.selectedEntry = nil
                detailPaneController.reset()
            }
        }
        .onChange(of: appState.pendingSelectEntry) { _, newValue in
            if let newValue {
                selectedEntry = newValue
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
        guard let selectedEntry else {
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
}
