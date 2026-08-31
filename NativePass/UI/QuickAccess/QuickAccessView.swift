import AppKit
import SwiftUI

struct QuickAccessView: View {
    @Environment(AppState.self) private var appState
    let onClose: (_ restorePreviousApplication: Bool) -> Void

    @State private var searchText = ""
    @State private var selectedEntry: String?
    @State private var isLoading = false
    @State private var decryptErrorSummary: String?
    @State private var closeAfterCopyTask: Task<Void, Never>?
    @State private var isUnlocking = false
    @State private var unlockError: String?
    @FocusState private var isSearchFocused: Bool

    private var isLocked: Bool {
        appState.appLock.isBlocking
    }

    private var filteredEntries: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return appState.entries.sorted()
        }
        return EntrySearch.ranked(appState.entries, query: query)
    }

    var body: some View {
        Group {
            if isLocked {
                lockedContent
            } else {
                unlockedContent
            }
        }
        .frame(width: 420, height: 420)
        .background(.ultraThinMaterial)
        .onDisappear { closeAfterCopyTask?.cancel() }
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .onKeyPress(keys: [.init("w")], phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            close()
            return .handled
        }
        .task(id: isLocked) {
            if isLocked {
                await unlockFromQuickAccess(autoPrompt: true)
            } else {
                requestSearchFocus()
            }
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.quaternary))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("NativePass is Locked")
                .font(.headline)

            Text("Unlock to search and copy passwords.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isUnlocking {
                ProgressView("Waiting for authentication…")
                    .controlSize(.small)
            }

            if let unlockError {
                Text(unlockError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await unlockFromQuickAccess(autoPrompt: false) }
            } label: {
                Label("Unlock", systemImage: "touchid")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isUnlocking)

            Spacer()
        }
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
    }

    private var unlockedContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            resultsList
            Divider()
            footer
        }
        .defaultFocus($isSearchFocused, true)
        .clipboardToast(message: appState.clipboard.lastCopyMessage) {
            appState.clipboard.dismissMessage()
        }
        .onKeyPress(.return) {
            if let selectedEntry {
                Task { await copyPassword(for: selectedEntry) }
            }
            return .handled
        }
        .onKeyPress(keys: [.init("o")], phases: .down) { press in
            guard press.modifiers.contains(.command), selectedEntry != nil else { return .ignored }
            openInMainWindow()
            return .handled
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Search entries…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
                .focusable(true)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Search")
            }

            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.quaternary))
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var resultsList: some View {
        Group {
            if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label("No Entries", systemImage: "key.slash")
                } description: {
                    Text(searchText.isEmpty ? "Your password store is empty." : "No matches for “\(searchText)”.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEntries.prefix(50), id: \.self, selection: $selectedEntry) { entry in
                    QuickAccessRow(
                        entry: entry,
                        username: appState.metadataCache.metadata(for: entry)?.username,
                        hasURL: appState.metadataCache.metadata(for: entry)?.url != nil,
                        hasOTP: appState.metadataCache.metadata(for: entry)?.hasOTP == true,
                        onCopy: { Task { await copyPassword(for: entry) } }
                    )
                    .tag(entry)
                    .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: selectedEntry) { _, _ in
            decryptErrorSummary = nil
        }
        .onChange(of: searchText) { _, _ in
            if let selectedEntry, !filteredEntries.contains(selectedEntry) {
                self.selectedEntry = filteredEntries.first
            } else if selectedEntry == nil {
                selectedEntry = filteredEntries.first
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            if let decryptErrorSummary {
                Text(decryptErrorSummary)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else {
                Text("esc close · ↵ copy · ⌘O open")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Button("Open in NativePass") {
                openInMainWindow()
            }
            .buttonStyle(.borderless)
            .disabled(selectedEntry == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func requestSearchFocus() {
        isSearchFocused = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            isSearchFocused = true
        }
    }

    private func close(restorePreviousApplication: Bool = true) {
        closeAfterCopyTask?.cancel()
        appState.clipboard.dismissMessage()
        onClose(restorePreviousApplication)
    }

    private func unlockFromQuickAccess(autoPrompt: Bool) async {
        guard appState.appLock.isBlocking, !isUnlocking else { return }

        isUnlocking = true
        unlockError = nil
        defer { isUnlocking = false }

        prepareWindowForAuthentication()
        if autoPrompt {
            try? await Task.sleep(for: .milliseconds(120))
        }

        let outcome = await appState.appLock.authenticateForManualUnlock()
        switch outcome {
        case .success:
            unlockError = nil
            requestSearchFocus()
        case .cancelled:
            break
        case .failed:
            unlockError = String(localized: "Authentication failed.")
        }
    }

    private func prepareWindowForAuthentication() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func copyPassword(for entry: String) async {
        guard !appState.appLock.isBlocking else { return }
        closeAfterCopyTask?.cancel()
        isLoading = true
        decryptErrorSummary = nil
        defer { isLoading = false }
        do {
            let loaded = try await appState.loadEntry(entry)
            appState.metadataCache.update(from: loaded)
            appState.clipboard.copy(loaded.password)
            closeAfterCopyTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                close()
            }
        } catch {
            let guide = DecryptFailureAnalyzer.analyze(
                error: error,
                entryName: entry,
                environment: appState.environment
            )
            decryptErrorSummary = guide.shortSummary
        }
    }

    private func openInMainWindow() {
        guard !appState.appLock.isBlocking else { return }
        guard let selectedEntry else { return }
        closeAfterCopyTask?.cancel()
        appState.requestSelectEntry(selectedEntry)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
        close(restorePreviousApplication: false)
    }
}

private struct QuickAccessRow: View {
    let entry: String
    let username: String?
    let hasURL: Bool
    let hasOTP: Bool
    let onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hasURL ? "globe" : "key.fill")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(PassFolderNode.entryDisplayName(entry))
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if let username, !username.isEmpty {
                    Text(username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if entry.contains("/") {
                    Text(entry)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if hasOTP {
                Image(systemName: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .help("Copy Password")
            .opacity(isHovered ? 1 : 0.35)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
