import SwiftUI
import AppKit

struct EntryDetailView: View {
    @Environment(AppState.self) private var appState

    let entryName: String
    var detailController: DetailPaneController

    @State private var entry: PassEntry?
    @State private var isLoading = false
    @State private var recoveryGuide: DecryptRecoveryGuide?
    @State private var isEditing = false
    /// Shared Form/Raw mode for both viewing and editing.
    @State private var showRaw = false
    @State private var draft: EntryEditDraft?
    @State private var rawDraft = ""
    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var isPasswordRevealed = false
    @State private var showDeleteConfirm = false
    @State private var actionError: String?

    private var canSaveCurrentEdit: Bool {
        if showRaw {
            return !isSaving
        }
        return (draft?.isValid ?? false) && !isSaving
    }

    private var showsModeToggle: Bool {
        entry != nil && recoveryGuide == nil && !isLoading
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Decrypting…")
            } else if let recoveryGuide {
                DecryptFailureView(guide: recoveryGuide) {
                    Task { await loadEntry() }
                }
            } else if let entry {
                entryContent(entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .overlay(alignment: .topTrailing) {
                        if showsModeToggle {
                            modeToggle
                                .padding(.top, 8)
                                .padding(.trailing, 20)
                        }
                    }
            } else {
                PassEmptyState(
                    title: String(localized: "No Entry Selected"),
                    systemImage: "key",
                    description: String(localized: "Select a password from the list.")
                )
            }
        }
        .navigationTitle("")
        .toolbar(removing: .title)
        .onAppear { syncDetailChrome() }
        .onChange(of: isEditing) { _, _ in syncDetailChrome() }
        .onChange(of: showRaw) { _, _ in syncDetailChrome() }
        .onChange(of: isLoading) { _, _ in syncDetailChrome() }
        .onChange(of: isSaving) { _, _ in syncDetailChrome() }
        .onChange(of: entry?.name) { _, _ in syncDetailChrome() }
        .onChange(of: recoveryGuide?.title) { _, _ in syncDetailChrome() }
        .onChange(of: draft?.isValid) { _, _ in syncDetailChrome() }
        .onChange(of: rawDraft) { _, _ in syncDetailChrome() }
        .onDisappear { detailController.reset() }
        .task(id: entryName) {
            resetEditState()
            showRaw = false
            await loadEntry()
        }
        .confirmationDialog(
            String(localized: "Delete \"\(entryName)\"?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteEntry() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the entry from your password store.")
        }
        .alert("Error", isPresented: .init(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    private func syncDetailChrome() {
        let canShowActions = entry != nil && recoveryGuide == nil && !isLoading
        detailController.showEditButton = canShowActions && !isEditing
        detailController.isEditing = isEditing
        detailController.canSave = canSaveCurrentEdit
        detailController.configureHandlers(
            onEdit: { beginEdit() },
            onCancel: { cancelEdit() },
            onSave: { Task { await saveEdit() } }
        )
    }

    private var modeToggle: some View {
        Button {
            if showRaw {
                switchToFormMode()
            } else {
                switchToRawMode()
            }
        } label: {
            Text(showRaw ? "Form" : "Raw")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(showRaw ? "Show structured form" : "Show raw entry text")
    }

    @ViewBuilder
    private func entryContent(_ entry: PassEntry) -> some View {
        let heroPath = isEditing ? (draft?.entryPath ?? entry.name) : entry.name

        if isEditing && showRaw {
            rawEditLayout(entry: entry, heroPath: heroPath)
        } else if !isEditing && showRaw {
            rawViewLayout(entry: entry, heroPath: heroPath)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    EntryHeroHeader(entryPath: heroPath)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isEditing, let draftBinding {
                        editingContent(draftBinding)
                    } else {
                        viewingContent(entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    /// View mode: card height follows content; outer scroll if the page is taller than the pane.
    @ViewBuilder
    private func rawViewLayout(entry: PassEntry, heroPath: String) -> some View {
        GeometryReader { geo in
            let verticalChrome: CGFloat = 24
            let estimatedHero: CGFloat = 100
            let maxBody = max(geo.size.height - estimatedHero - verticalChrome, 120)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    EntryHeroHeader(entryPath: heroPath)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    EntryRawSection(
                        entryName: entryName,
                        rawContent: entry.rawContent,
                        isEditing: false,
                        maxBodyHeight: maxBody,
                        editText: $rawDraft,
                        onCopyAll: { copyRaw(entry.rawContent) }
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    /// Edit mode: editor fills remaining detail height.
    @ViewBuilder
    private func rawEditLayout(entry: PassEntry, heroPath: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EntryHeroHeader(entryPath: heroPath)
                .frame(maxWidth: .infinity, alignment: .leading)

            EntryRawSection(
                entryName: entryName,
                rawContent: entry.rawContent,
                isEditing: true,
                editText: $rawDraft,
                onCopyAll: { copyRaw(entry.rawContent) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            rawDeleteCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var rawDeleteCard: some View {
        DetailGroupCard {
            DetailGroupDestructiveRow(title: "Delete") {
                showDeleteConfirm = true
            }
        }
    }

    @ViewBuilder
    private func editingContent(_ draftBinding: Binding<EntryEditDraft>) -> some View {
        DetailGroupCard {
            LocationDetailSection(entryPath: draftBinding.entryPath)
            DetailGroupDivider()
            PasswordDetailSection(
                password: draftBinding.password,
                isEditing: true,
                isRevealed: $isPasswordRevealed,
                isGenerating: isGenerating,
                onCopy: { appState.clipboard.copy(draftBinding.wrappedValue.password) },
                onRevealToggle: togglePasswordReveal,
                onGenerate: generatePassword
            )

            if !draftBinding.wrappedValue.fields.isEmpty {
                DetailGroupDivider()
                EditableFieldsSection(fields: draftBinding.fields)
            } else {
                DetailGroupDivider()
                DetailGroupActionRow(title: "Add Field") {
                    draft?.fields.append(EditableField(key: "", value: ""))
                }
            }
        }

        if appState.registry.hasOTP || draftBinding.wrappedValue.otpauthLine != nil {
            VerificationCodeDetailSection(
                entryName: entryName,
                hasOTPMarker: draftBinding.wrappedValue.otpauthLine != nil,
                otpauthLine: draftBinding.wrappedValue.otpauthLine,
                isEditing: true,
                pendingOTPURI: draftBinding.pendingOTPURI
            )
        }

        DetailGroupCard {
            DetailGroupDestructiveRow(title: "Delete") {
                showDeleteConfirm = true
            }
        }
    }

    @ViewBuilder
    private func viewingContent(_ entry: PassEntry) -> some View {
        DetailGroupCard {
            PasswordDetailSection(
                password: .constant(entry.password),
                isEditing: false,
                isRevealed: $isPasswordRevealed,
                copyFeedbackScope: entry.name,
                onCopy: { appState.clipboard.copy(entry.password, showToast: false) },
                onRevealToggle: togglePasswordReveal,
                onGenerate: nil
            )

            if !entry.fields.isEmpty {
                DetailGroupDivider()
                EntryFieldsViewSection(
                    fields: entry.fields,
                    onCopy: { appState.clipboard.copy($0) }
                )
            }
        }

        if entry.hasOTPMarker {
            VerificationCodeDetailSection(
                entryName: entry.name,
                hasOTPMarker: true,
                otpauthLine: entry.otpauthLine,
                isEditing: false,
                pendingOTPURI: .constant("")
            )
        }
    }

    private var draftBinding: Binding<EntryEditDraft>? {
        guard let draft else { return nil }
        return Binding(
            get: { draft },
            set: { self.draft = $0 }
        )
    }

    private func copyRaw(_ raw: String) {
        appState.clipboard.copy(raw, showToast: false)
        NotificationCenter.default.post(
            name: .nativePassPasswordCopiedInline,
            object: nil,
            userInfo: ["scope": "\(entryName)-raw"]
        )
    }

    private func switchToRawMode() {
        if isEditing, let draft {
            rawDraft = draft.toSerializedContent()
        }
        showRaw = true
    }

    private func switchToFormMode() {
        if isEditing {
            let path = draft?.entryPath ?? entry?.name ?? entryName
            let pending = draft?.pendingOTPURI ?? ""
            let parsed = PassEntryParser.parse(name: path, content: rawDraft)
            var next = EntryEditDraft.from(parsed)
            next.entryPath = path
            next.pendingOTPURI = pending
            draft = next
        }
        showRaw = false
    }

    private func beginEdit() {
        guard let entry else { return }
        draft = EntryEditDraft.from(entry)
        rawDraft = entry.rawContent
        isEditing = true
        isPasswordRevealed = false
    }

    private func cancelEdit() {
        resetEditState()
    }

    private func resetEditState() {
        isEditing = false
        draft = nil
        rawDraft = ""
        isPasswordRevealed = false
        isGenerating = false
    }

    private func togglePasswordReveal() {
        isPasswordRevealed.toggle()
        if isPasswordRevealed {
            schedulePasswordHide()
        }
    }

    private func schedulePasswordHide() {
        let delay = AppPreferences.revealHideDelay
        guard delay > 0 else { return }
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                if isPasswordRevealed {
                    isPasswordRevealed = false
                }
            }
        }
    }

    private func loadEntry() async {
        isLoading = true
        recoveryGuide = nil
        if !isEditing {
            entry = nil
        }
        defer { isLoading = false }

        do {
            let loaded = try await appState.loadEntry(entryName)
            if !isEditing {
                entry = loaded
            }
            appState.metadataCache.update(from: loaded)
        } catch {
            recoveryGuide = DecryptFailureAnalyzer.analyze(
                error: error,
                entryName: entryName,
                environment: appState.environment
            )
        }
    }

    private func saveEdit() async {
        if showRaw {
            await saveRawEdit()
        } else {
            await saveFormEdit()
        }
    }

    private func saveRawEdit() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await appState.saveEntry(entryName, content: rawDraft, force: true)
            resetEditState()
            showRaw = true
            await appState.afterMutation(selectEntry: entryName)
            await loadEntry()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func saveFormEdit() async {
        guard let draft else { return }
        let newPath = draft.trimmedPath
        guard draft.isValid else { return }

        isSaving = true
        defer { isSaving = false }

        let content = draft.toSerializedContent()
        let pendingOTP = draft.pendingOTPURI.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if newPath != entryName {
                try await appState.renameEntry(from: entryName, to: newPath)
            }
            try await appState.saveEntry(newPath, content: content, force: true)

            if !pendingOTP.isEmpty, draft.otpauthLine == nil {
                try await appState.cli.otpAppend(newPath, uri: pendingOTP)
            }

            resetEditState()
            showRaw = false
            await appState.afterMutation(selectEntry: newPath)
            if entryName == newPath {
                await loadEntry()
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func generatePassword() {
        isGenerating = true
        defer { isGenerating = false }
        do {
            draft?.password = try PasswordGenerator.generate(
                length: AppPreferences.generatedPasswordLength
            )
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func deleteEntry() async {
        do {
            try await appState.removeEntry(entryName)
            resetEditState()
            await appState.afterMutation()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
