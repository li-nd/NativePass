import AppKit
import SwiftUI

struct QuickAccessView: View {
    @Environment(AppState.self) private var appState
    let onClose: (_ restorePreviousApplication: Bool) -> Void

    fileprivate enum FocusTarget: Hashable {
        case search
        case list
    }

    @State private var searchText = ""
    @State private var selectedEntry: String?
    @State private var isLoading = false
    @State private var decryptErrorSummary: String?
    @State private var closeAfterActionTask: Task<Void, Never>?
    @State private var isUnlocking = false
    @State private var unlockError: String?
    @FocusState private var focusTarget: FocusTarget?

    private var isLocked: Bool {
        appState.appLock.isBlocking
    }

    private var autoTypeEnabled: Bool {
        AppPreferences.autoTypeEnabled
    }

    private var primaryAction: QuickAccessPrimaryAction {
        AppPreferences.effectiveQuickAccessPrimaryAction
    }

    private var filteredEntries: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return appState.entries.sorted()
        }
        return EntrySearch.ranked(appState.entries, query: query)
    }

    private var visibleEntries: [String] {
        Array(filteredEntries.prefix(50))
    }

    private var footerHint: String {
        if autoTypeEnabled {
            switch primaryAction {
            case .copy:
                return String(localized: "esc · ↑↓ · ⇥ · ↵ copy · ⌘↵ type · ⌘O")
            case .autoType:
                return String(localized: "esc · ↑↓ · ⇥ · ↵ type · ⌘↵ copy · ⌘O")
            }
        }
        return String(localized: "esc · ↑↓ · ⇥ · ↵ copy · ⌘O")
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
        .onDisappear { closeAfterActionTask?.cancel() }
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
        .defaultFocus($focusTarget, .search)
        .clipboardToast(message: appState.clipboard.lastCopyMessage) {
            appState.clipboard.dismissMessage()
        }
        .background {
            QuickAccessKeyboardMonitor(
                focusTarget: focusTarget,
                onMoveSelection: { moveSelection(delta: $0) },
                onFocusList: {
                    ensureSelectionExists()
                    guard !visibleEntries.isEmpty else { return false }
                    focusTarget = .list
                    return true
                },
                onFocusSearch: {
                    focusTarget = .search
                }
            )
        }
        .onKeyPress(keys: [.return], phases: .down) { press in
            guard let selectedEntry else { return .handled }
            if press.modifiers.contains(.command), autoTypeEnabled {
                Task { await performSecondaryAction(for: selectedEntry) }
            } else {
                Task { await performPrimaryAction(for: selectedEntry) }
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
                .focused($focusTarget, equals: .search)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    focusTarget = .search
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
            if visibleEntries.isEmpty {
                ContentUnavailableView {
                    Label("No Entries", systemImage: "key.slash")
                } description: {
                    Text(searchText.isEmpty
                         ? String(localized: "Your password store is empty.")
                         : String(localized: "No matches for “\(searchText)”."))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(visibleEntries, id: \.self, selection: $selectedEntry) { entry in
                        QuickAccessRow(
                            entry: entry,
                            username: appState.metadataCache.metadata(for: entry)?.username,
                            hasURL: appState.metadataCache.metadata(for: entry)?.url != nil,
                            hasOTP: appState.metadataCache.metadata(for: entry)?.hasOTP == true,
                            showAutoType: autoTypeEnabled,
                            onCopy: { Task { await copyPassword(for: entry) } },
                            onAutoType: { Task { await autoTypePassword(for: entry) } }
                        )
                        .tag(entry)
                        .id(entry)
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .focused($focusTarget, equals: .list)
                    .focusable(true)
                    .onChange(of: selectedEntry) { _, newValue in
                        decryptErrorSummary = nil
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: searchText) { _, _ in
            syncSelectionToVisibleEntries()
        }
        .onAppear {
            syncSelectionToVisibleEntries()
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
                Text(footerHint)
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
        focusTarget = .search
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            focusTarget = .search
        }
    }

    private func ensureSelectionExists() {
        if selectedEntry == nil || !(visibleEntries.contains(selectedEntry ?? "")) {
            selectedEntry = visibleEntries.first
        }
    }

    private func syncSelectionToVisibleEntries() {
        if let selectedEntry, visibleEntries.contains(selectedEntry) {
            return
        }
        selectedEntry = visibleEntries.first
    }

    private func moveSelection(delta: Int) {
        let entries = visibleEntries
        guard !entries.isEmpty else { return }

        if let selectedEntry, let index = entries.firstIndex(of: selectedEntry) {
            let next = min(max(index + delta, 0), entries.count - 1)
            self.selectedEntry = entries[next]
        } else {
            selectedEntry = delta >= 0 ? entries.first : entries.last
        }
    }

    private func close(restorePreviousApplication: Bool = true) {
        closeAfterActionTask?.cancel()
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

    private func performPrimaryAction(for entry: String) async {
        switch primaryAction {
        case .copy:
            await copyPassword(for: entry)
        case .autoType:
            await autoTypePassword(for: entry)
        }
    }

    private func performSecondaryAction(for entry: String) async {
        switch primaryAction {
        case .copy:
            await autoTypePassword(for: entry)
        case .autoType:
            await copyPassword(for: entry)
        }
    }

    private func copyPassword(for entry: String) async {
        guard !appState.appLock.isBlocking else { return }
        closeAfterActionTask?.cancel()
        isLoading = true
        decryptErrorSummary = nil
        defer { isLoading = false }
        do {
            let loaded = try await appState.loadEntry(entry)
            appState.metadataCache.update(from: loaded)
            appState.clipboard.copy(loaded.password)
            closeAfterActionTask = Task { @MainActor in
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

    private func autoTypePassword(for entry: String) async {
        guard !appState.appLock.isBlocking else { return }
        guard AppPreferences.autoTypeEnabled else { return }

        if !AutoTypeService.isTrusted(prompt: false) {
            _ = AutoTypeService.isTrusted(prompt: true)
            if !AutoTypeService.isTrusted(prompt: false) {
                decryptErrorSummary = String(localized: "Allow Accessibility for NativePass to use Auto-Type.")
                return
            }
        }

        closeAfterActionTask?.cancel()
        isLoading = true
        decryptErrorSummary = nil
        defer { isLoading = false }

        let password: String
        do {
            let loaded = try await appState.loadEntry(entry)
            appState.metadataCache.update(from: loaded)
            password = loaded.password
        } catch {
            let guide = DecryptFailureAnalyzer.analyze(
                error: error,
                entryName: entry,
                environment: appState.environment
            )
            decryptErrorSummary = guide.shortSummary
            return
        }

        close(restorePreviousApplication: true)

        let delay = AppPreferences.autoTypeDelayMilliseconds
        if delay > 0 {
            try? await Task.sleep(for: .milliseconds(delay))
        }

        do {
            try AutoTypeService.typeText(password)
        } catch {
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = String(localized: "Auto-Type Failed")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: String(localized: "OK"))
                if error is AutoTypeError {
                    alert.addButton(withTitle: String(localized: "Open Settings"))
                }
                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    AutoTypeService.openAccessibilitySettings()
                }
            }
        }
    }

    private func openInMainWindow() {
        guard !appState.appLock.isBlocking else { return }
        guard let selectedEntry else { return }
        closeAfterActionTask?.cancel()
        appState.requestSelectEntry(selectedEntry)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
        close(restorePreviousApplication: false)
    }
}

/// Local key monitor: system key-repeat for ↑/↓ in search, and Tab focus transfer
/// (AppKit TextField swallows Tab before SwiftUI `onKeyPress`).
private struct QuickAccessKeyboardMonitor: NSViewRepresentable {
    var focusTarget: QuickAccessView.FocusTarget?
    var onMoveSelection: (Int) -> Void
    /// Returns `false` if list focus was refused (e.g. empty results).
    var onFocusList: () -> Bool
    var onFocusSearch: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.hostView = view
        context.coordinator.onMoveSelection = onMoveSelection
        context.coordinator.onFocusList = onFocusList
        context.coordinator.onFocusSearch = onFocusSearch
        context.coordinator.focusTarget = focusTarget
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.onMoveSelection = onMoveSelection
        context.coordinator.onFocusList = onFocusList
        context.coordinator.onFocusSearch = onFocusSearch
        context.coordinator.focusTarget = focusTarget
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var hostView: NSView?
        var focusTarget: QuickAccessView.FocusTarget?
        var onMoveSelection: ((Int) -> Void)?
        var onFocusList: (() -> Bool)?
        var onFocusSearch: (() -> Void)?
        private var monitor: Any?

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let hostView, hostView.window != nil else { return event }
            if let eventWindow = event.window, eventWindow !== hostView.window {
                return event
            }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

            // Tab / Shift+Tab — transfer focus between search and list
            if event.keyCode == 48 {
                let nonShift = modifiers.subtracting(.shift)
                guard nonShift.isEmpty else { return event }

                if modifiers.contains(.shift) || focusTarget == .list {
                    onFocusSearch?()
                    DispatchQueue.main.async { [weak self] in
                        self?.makeSearchFirstResponder()
                    }
                } else {
                    guard onFocusList?() == true else { return nil }
                    DispatchQueue.main.async { [weak self] in
                        self?.makeListFirstResponder()
                    }
                }
                return nil
            }

            // ↑ / ↓ while search is focused (including key-repeat)
            guard focusTarget == .search else { return event }
            guard modifiers.isEmpty else { return event }

            let delta: Int
            switch event.keyCode {
            case 125: delta = 1
            case 126: delta = -1
            default: return event
            }
            onMoveSelection?(delta)
            return nil
        }

        private func makeSearchFirstResponder() {
            guard let window = hostView?.window,
                  let field = Self.findEditableTextField(in: window.contentView) else { return }
            window.makeFirstResponder(field)
        }

        private func makeListFirstResponder() {
            guard let window = hostView?.window else { return }
            if let table = Self.findTableView(in: window.contentView) {
                window.makeFirstResponder(table)
                return
            }
            // Fall back: resign text field so List can take SwiftUI focus.
            if let field = Self.findEditableTextField(in: window.contentView) {
                field.resignFirstResponder()
            }
            window.makeFirstResponder(nil)
        }

        private static func findEditableTextField(in root: NSView?) -> NSTextField? {
            guard let root else { return nil }
            if let textField = root as? NSTextField, textField.isEditable {
                return textField
            }
            for subview in root.subviews {
                if let found = findEditableTextField(in: subview) {
                    return found
                }
            }
            return nil
        }

        private static func findTableView(in root: NSView?) -> NSTableView? {
            guard let root else { return nil }
            if let table = root as? NSTableView {
                return table
            }
            for subview in root.subviews {
                if let found = findTableView(in: subview) {
                    return found
                }
            }
            return nil
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

private struct QuickAccessRow: View {
    let entry: String
    let username: String?
    let hasURL: Bool
    let hasOTP: Bool
    var showAutoType: Bool = false
    let onCopy: () -> Void
    var onAutoType: (() -> Void)?

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

            if showAutoType, let onAutoType {
                Button(action: onAutoType) {
                    Image(systemName: "keyboard")
                        .font(.body)
                }
                .buttonStyle(.borderless)
                .help("Type Password")
                .opacity(isHovered ? 1 : 0.35)
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
