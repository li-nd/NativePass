import AppKit
import SwiftUI

struct QuickAccessView: View {
    @Environment(AppState.self) private var appState
    /// Returns the restored frontmost app when `restorePreviousApplication` is true.
    let onClose: (_ restorePreviousApplication: Bool) -> NSRunningApplication?

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
    @State private var fieldPicker: FieldPickerSession?
    @State private var isWaitingToReleaseModifiers = false
    @FocusState private var focusTarget: FocusTarget?

    private struct FieldPickerSession {
        var entryName: String
        var choices: [QuickAccessFieldChoice]
        var selectedID: QuickAccessPickerItemID
        var loadedEntry: PassEntry?
        var otpInfo: OTPInfo?
        var isLoading: Bool
    }

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
                return String(localized: "esc · ↑↓ · ⇥ · ↵ copy · ⌘↵ type · ⌥⌘↵ more · ⌘O")
            case .autoType:
                return String(localized: "esc · ↑↓ · ⇥ · ↵ type · ⌘↵ copy · ⌥⌘↵ more · ⌘O")
            }
        }
        return String(localized: "esc · ↑↓ · ⇥ · ↵ copy · ⌥⌘↵ more · ⌘O")
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
            if isWaitingToReleaseModifiers {
                isWaitingToReleaseModifiers = false
                return .handled
            }
            if fieldPicker != nil {
                dismissFieldPicker()
                return .handled
            }
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
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                resultsList
                Divider()
                footer
            }

            if isWaitingToReleaseModifiers {
                releaseModifiersOverlay
            } else if fieldPicker != nil {
                fieldPickerOverlay
            }
        }
        .defaultFocus($focusTarget, .search)
        .clipboardToast(message: appState.clipboard.lastCopyMessage) {
            appState.clipboard.dismissMessage()
        }
        .background {
            LocalKeyboardMonitor { event, window in
                handleQuickAccessKeyEvent(event, window: window)
            }
        }
        .onKeyPress(keys: [.return], phases: .down) { press in
            if fieldPicker != nil {
                let useSecondary = press.modifiers.contains(.command) && autoTypeEnabled
                Task { await activateFieldPickerSelection(useSecondary: useSecondary) }
                return .handled
            }

            guard let selectedEntry else { return .handled }

            let modifiers = press.modifiers
            if modifiers.contains(.option), modifiers.contains(.command) {
                Task { await openFieldPicker(for: selectedEntry) }
                return .handled
            }

            if modifiers.contains(.command), autoTypeEnabled {
                Task { await performSecondaryAction(for: selectedEntry) }
            } else {
                Task { await performPrimaryAction(for: selectedEntry) }
            }
            return .handled
        }
        .onKeyPress(keys: [.init("o")], phases: .down) { press in
            guard fieldPicker == nil else { return .handled }
            guard press.modifiers.contains(.command), selectedEntry != nil else { return .ignored }
            openInMainWindow()
            return .handled
        }
    }

    private var releaseModifiersOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "command")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Release ⌘ to type")
                    .font(.headline)

                Text("Auto-Type starts after you release Command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "esc cancel"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(width: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Release Command to type"))
    }

    private var fieldPickerHint: String {
        if autoTypeEnabled {
            switch primaryAction {
            case .copy:
                return String(localized: "↑↓ · ↵ copy · ⌘↵ type · esc")
            case .autoType:
                return String(localized: "↑↓ · ↵ type · ⌘↵ copy · esc")
            }
        }
        return String(localized: "↑↓ · ↵ copy · esc")
    }

    private var fieldPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissFieldPicker()
                }

            VStack(alignment: .leading, spacing: 10) {
                if let session = fieldPicker, !session.isLoading {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(session.choices) { choice in
                                    fieldPickerRow(
                                        choice,
                                        selected: choice.id == session.selectedID,
                                        otpInfo: session.otpInfo
                                    )
                                    .id(choice.id)
                                    .onTapGesture {
                                        handleFieldPickerActivate(choiceID: choice.id, useSecondary: false)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                        .onChange(of: session.selectedID) { _, newValue in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Text(fieldPickerHint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(width: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        }
    }

    private func fieldPickerRow(
        _ choice: QuickAccessFieldChoice,
        selected: Bool,
        otpInfo: OTPInfo?
    ) -> some View {
        HStack(spacing: 8) {
            Text(choice.label)
                .font(.body.weight(selected ? .semibold : .regular))
                .lineLimit(1)

            Spacer(minLength: 8)

            if AppPreferences.showQuickAccessFieldPreviews {
                fieldPickerPreview(for: choice, otpInfo: otpInfo)
                    .layoutPriority(-1)
            }

            if selected {
                Image(systemName: "return")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.22) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func fieldPickerPreview(
        for choice: QuickAccessFieldChoice,
        otpInfo: OTPInfo?
    ) -> some View {
        if case .otp = choice.id, let otpInfo {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let code = TOTPGenerator.generateCode(from: otpInfo, at: context.date)
                Text(code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.default, value: code)
            }
        } else {
            Text(choice.preview)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func handleQuickAccessKeyEvent(_ event: NSEvent, window: NSWindow?) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if isWaitingToReleaseModifiers {
            if event.keyCode == KeyboardKeyCode.escape {
                isWaitingToReleaseModifiers = false
                return nil
            }
            // Swallow other keys while prompting to release ⌘.
            return nil
        }

        if fieldPicker != nil {
            return handleFieldPickerKeyEvent(event, modifiers: modifiers)
        }

        // Tab / Shift+Tab — transfer focus between search and list
        if event.keyCode == KeyboardKeyCode.tab {
            let nonShift = modifiers.subtracting(.shift)
            guard nonShift.isEmpty else { return event }

            if modifiers.contains(.shift) || focusTarget == .list {
                focusTarget = .search
                DispatchQueue.main.async {
                    AppKitFocusHelper.focusEditableSearchField(in: window)
                }
            } else {
                ensureSelectionExists()
                guard !visibleEntries.isEmpty else { return nil }
                focusTarget = .list
                DispatchQueue.main.async {
                    // Quick Access has a single results table in its panel.
                    AppKitFocusHelper.focusTableNearAnchor(
                        in: window,
                        anchorID: FocusAnchorID.quickAccessList
                    )
                }
            }
            return nil
        }

        // ⌥⌘↵ — open field picker (backup if SwiftUI onKeyPress misses it)
        if event.keyCode == KeyboardKeyCode.returnKey,
           modifiers.contains(.option),
           modifiers.contains(.command),
           let selectedEntry {
            Task { await openFieldPicker(for: selectedEntry) }
            return nil
        }

        // ↑ / ↓ while search is focused (including key-repeat)
        guard focusTarget == .search else { return event }
        guard modifiers.isEmpty else { return event }

        let delta: Int
        switch event.keyCode {
        case KeyboardKeyCode.downArrow: delta = 1
        case KeyboardKeyCode.upArrow: delta = -1
        default: return event
        }
        moveSelection(delta: delta)
        return nil
    }

    private func handleFieldPickerKeyEvent(
        _ event: NSEvent,
        modifiers: NSEvent.ModifierFlags
    ) -> NSEvent? {
        if event.keyCode == KeyboardKeyCode.escape {
            dismissFieldPicker()
            return nil
        }

        if event.keyCode == KeyboardKeyCode.returnKey {
            if modifiers.contains(.option), modifiers.contains(.command) {
                return nil
            }
            let useSecondary = modifiers.contains(.command) && autoTypeEnabled
            guard modifiers.isEmpty || modifiers == [.command] else {
                return nil
            }
            Task { await activateFieldPickerSelection(useSecondary: useSecondary) }
            return nil
        }

        guard modifiers.isEmpty else { return nil }

        let delta: Int
        switch event.keyCode {
        case KeyboardKeyCode.downArrow: delta = 1
        case KeyboardKeyCode.upArrow: delta = -1
        default: return nil
        }
        moveFieldPickerSelection(delta: delta)
        return nil
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
                            onAutoType: { Task { await autoTypePassword(for: entry) } },
                            onCopyOTP: { Task { await copyOTP(for: entry) } },
                            onMore: {
                                selectedEntry = entry
                                Task { await openFieldPicker(for: entry) }
                            }
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            Button("Open in NativePass") {
                openInMainWindow()
            }
            .buttonStyle(.borderless)
            .fixedSize()
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
        var selection = selectedEntry
        ListSelectionMovement.move(selection: &selection, in: visibleEntries, delta: delta)
        selectedEntry = selection
    }

    private func close(restorePreviousApplication: Bool = true) -> NSRunningApplication? {
        closeAfterActionTask?.cancel()
        appState.clipboard.dismissMessage()
        return onClose(restorePreviousApplication)
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

    private func openFieldPicker(for entry: String) async {
        guard !appState.appLock.isBlocking else { return }
        if fieldPicker?.entryName == entry, fieldPicker?.isLoading == true {
            return
        }
        closeAfterActionTask?.cancel()
        decryptErrorSummary = nil
        fieldPicker = FieldPickerSession(
            entryName: entry,
            choices: [],
            selectedID: .fullEntry,
            loadedEntry: nil,
            otpInfo: nil,
            isLoading: true
        )

        do {
            let loaded = try await appState.loadEntry(entry)
            appState.metadataCache.update(from: loaded)
            let choices = QuickAccessFieldResolver.choices(from: loaded)
            let otpInfo: OTPInfo?
            if loaded.hasOTPMarker {
                otpInfo = try? await OTPInfoLoader.resolve(
                    entryName: entry,
                    otpauthLine: loaded.otpauthLine,
                    otpService: appState.otp
                )
            } else {
                otpInfo = nil
            }
            fieldPicker = FieldPickerSession(
                entryName: entry,
                choices: choices,
                selectedID: choices.first?.id ?? .fullEntry,
                loadedEntry: loaded,
                otpInfo: otpInfo,
                isLoading: false
            )
        } catch {
            fieldPicker = nil
            let guide = DecryptFailureAnalyzer.analyze(
                error: error,
                entryName: entry,
                environment: appState.environment
            )
            decryptErrorSummary = guide.shortSummary
        }
    }

    private func dismissFieldPicker() {
        fieldPicker = nil
    }

    private func moveFieldPickerSelection(delta: Int) {
        guard var session = fieldPicker else { return }
        let ids = session.choices.map(\.id)
        guard !ids.isEmpty else { return }
        var selection: QuickAccessPickerItemID? = session.selectedID
        ListSelectionMovement.move(selection: &selection, in: ids, delta: delta)
        if let selection {
            session.selectedID = selection
            fieldPicker = session
        }
    }

    private func handleFieldPickerActivate(choiceID: QuickAccessPickerItemID, useSecondary: Bool) {
        guard var session = fieldPicker else { return }
        session.selectedID = choiceID
        fieldPicker = session
        Task { await activateFieldPickerSelection(useSecondary: useSecondary) }
    }

    private func activateFieldPickerSelection(useSecondary: Bool) async {
        guard let session = fieldPicker, !session.isLoading else { return }
        guard let choice = session.choices.first(where: { $0.id == session.selectedID }) else {
            return
        }
        await confirmFieldPickerSelection(choice: choice, useSecondary: useSecondary)
    }

    private func confirmFieldPickerSelection(
        choice: QuickAccessFieldChoice,
        useSecondary: Bool
    ) async {
        guard let session = fieldPicker else { return }

        let value: String
        do {
            value = try await resolveFieldValue(
                choice,
                entry: session.loadedEntry,
                entryName: session.entryName,
                otpInfo: session.otpInfo,
                forTyping: {
                    if !autoTypeEnabled { return false }
                    if useSecondary { return primaryAction == .copy }
                    return primaryAction == .autoType
                }()
            )
        } catch {
            decryptErrorSummary = error.localizedDescription
            return
        }

        fieldPicker = nil

        let shouldAutoType: Bool
        if !autoTypeEnabled {
            shouldAutoType = false
        } else if useSecondary {
            shouldAutoType = primaryAction == .copy
        } else {
            shouldAutoType = primaryAction == .autoType
        }

        if shouldAutoType {
            await autoTypeValue(value)
        } else {
            await copyValue(value)
        }
    }

    private func resolveFieldValue(
        _ choice: QuickAccessFieldChoice,
        entry: PassEntry?,
        entryName: String,
        otpInfo: OTPInfo?,
        forTyping: Bool
    ) async throws -> String {
        switch choice.id {
        case .otp:
            let resolved = try await {
                if let otpInfo { return otpInfo }
                return try await OTPInfoLoader.resolve(
                    entryName: entryName,
                    otpauthLine: entry?.otpauthLine,
                    otpService: appState.otp
                )
            }()
            return TOTPGenerator.generateCode(from: resolved)

        case .fullEntry:
            if forTyping, let entry {
                return QuickAccessFieldResolver.typingContent(from: entry)
            }
            if let value = choice.value { return value }
            throw PassError.parseFailed(String(localized: "No value for this field."))

        case .password, .username, .url, .custom:
            if let value = choice.value { return value }
            throw PassError.parseFailed(String(localized: "No value for this field."))
        }
    }

    private func copyPassword(for entry: String) async {
        await deliverPassword(for: entry, mode: .copy)
    }

    private func copyOTP(for entry: String) async {
        guard !appState.appLock.isBlocking else { return }
        closeAfterActionTask?.cancel()
        isLoading = true
        decryptErrorSummary = nil
        defer { isLoading = false }

        do {
            let loaded = try await appState.loadEntry(entry)
            appState.metadataCache.update(from: loaded)
            guard loaded.hasOTPMarker else {
                decryptErrorSummary = String(localized: "No OTP for this entry.")
                return
            }
            let code = try await resolveFieldValue(
                QuickAccessFieldChoice(id: .otp, label: String(localized: "OTP"), value: nil),
                entry: loaded,
                entryName: entry,
                otpInfo: nil,
                forTyping: false
            )
            await copyValue(code)
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
        await deliverPassword(for: entry, mode: .autoType)
    }

    private enum DeliverMode {
        case copy
        case autoType
    }

    private func deliverPassword(for entry: String, mode: DeliverMode) async {
        guard !appState.appLock.isBlocking else { return }
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

        switch mode {
        case .copy:
            await copyValue(password)
        case .autoType:
            await autoTypeValue(password)
        }
    }

    private func copyValue(_ value: String) async {
        guard !appState.appLock.isBlocking else { return }
        closeAfterActionTask?.cancel()
        appState.clipboard.copy(value)
        closeAfterActionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            close()
        }
    }

    private func autoTypeValue(_ value: String) async {
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
        dismissFieldPicker()

        // Keep Quick Access visible with a prompt while ⌘ is still held (⌘↵).
        if AutoTypeService.areTypeBlockingModifiersPressed() {
            isWaitingToReleaseModifiers = true
            let released = await AutoTypeService.waitForTypeBlockingModifiersReleased {
                isWaitingToReleaseModifiers
            }
            let cancelled = !isWaitingToReleaseModifiers
            isWaitingToReleaseModifiers = false
            if cancelled { return }
            // Timed out with ⌘ still down — still try after close; prepare path waits briefly again.
            _ = released
        }

        let targetApplication = close(restorePreviousApplication: true)

        if let targetApplication {
            await AutoTypeService.waitUntilFrontmost(targetApplication)
        }

        let delay = AppPreferences.autoTypeDelayMilliseconds
        if delay > 0 {
            try? await Task.sleep(for: .milliseconds(delay))
        }

        // Final safety check in case ⌘ was pressed again during the delay.
        if AutoTypeService.areTypeBlockingModifiersPressed() {
            _ = await AutoTypeService.waitForTypeBlockingModifiersReleased(timeoutMilliseconds: 1_500)
        }

        do {
            try AutoTypeService.typeText(value)
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
        dismissFieldPicker()
        appState.requestSelectEntry(selectedEntry)
        appState.revealMainWindow()
        close(restorePreviousApplication: false)
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
    var onCopyOTP: (() -> Void)?
    let onMore: () -> Void

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

            if hasOTP, let onCopyOTP {
                Button(action: onCopyOTP) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy OTP")
                .opacity(isHovered ? 1 : 0.55)
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

            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .help("More…")
            .opacity(isHovered ? 1 : 0.35)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
