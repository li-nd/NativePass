import AppKit
import SwiftUI

struct QuickAccessView: View {
    @Environment(AppState.self) private var appState
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var selectedEntry: String?
    @State private var loadedEntry: PassEntry?
    @State private var isLoading = false
    @State private var decryptErrorSummary: String?
    @FocusState private var isSearchFocused: Bool

    private var filteredEntries: [String] {
        let base = appState.entries.sorted()
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search entries…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)

            Divider()

            List(filteredEntries.prefix(50), id: \.self, selection: $selectedEntry) { entry in
                HStack {
                    EntryListRow(
                        entry: entry,
                        username: appState.metadataCache.metadata(for: entry)?.username,
                        hasURL: appState.metadataCache.metadata(for: entry)?.url != nil,
                        hasOTP: appState.metadataCache.metadata(for: entry)?.hasOTP == true
                    )
                    Spacer()
                    Button {
                        Task { await copyPassword(for: entry) }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy Password")
                }
                .tag(entry)
            }
            .listStyle(.plain)
            .frame(maxHeight: 240)
            .onChange(of: selectedEntry) { _, _ in
                loadedEntry = nil
                decryptErrorSummary = nil
            }

            Divider()

            HStack {
                if let decryptErrorSummary {
                    Text(decryptErrorSummary)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text("↵ copy password · ⌘O open")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Open in NativePass") {
                    openInMainWindow()
                }
                .disabled(selectedEntry == nil)
            }
            .padding(12)
        }
        .frame(width: 380, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .clipboardToast(message: appState.clipboard.lastCopyMessage) {
            appState.clipboard.dismissMessage()
        }
        .onAppear { isSearchFocused = true }
        .onKeyPress(.return) {
            if let selectedEntry {
                Task { await copyPassword(for: selectedEntry) }
            }
            return .handled
        }
        .onKeyPress(keys: [.init("o")], phases: .down) { press in
            if press.modifiers.contains(.command), selectedEntry != nil {
                openInMainWindow()
                return .handled
            }
            return .ignored
        }
    }

    private func copyPassword(for entry: String) async {
        isLoading = true
        decryptErrorSummary = nil
        defer { isLoading = false }
        do {
            let loaded = try await appState.loadEntry(entry)
            loadedEntry = loaded
            appState.metadataCache.update(from: loaded)
            appState.clipboard.copy(loaded.password)
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
        guard let selectedEntry else { return }
        appState.requestSelectEntry(selectedEntry)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
        onClose()
    }
}
