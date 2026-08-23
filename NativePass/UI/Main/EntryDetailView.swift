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
    @State private var draft: EntryEditDraft?
    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var isPasswordRevealed = false
    @State private var showDeleteConfirm = false
    @State private var actionError: String?

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
        .onChange(of: isLoading) { _, _ in syncDetailChrome() }
        .onChange(of: isSaving) { _, _ in syncDetailChrome() }
        .onChange(of: entry?.name) { _, _ in syncDetailChrome() }
        .onChange(of: recoveryGuide?.title) { _, _ in syncDetailChrome() }
        .onChange(of: draft?.isValid) { _, _ in syncDetailChrome() }
        .onDisappear { detailController.reset() }
        .task(id: entryName) {
            resetEditState()
            await loadEntry()
        }
        .confirmationDialog(
            "Delete \"\(entryName)\"?",
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
        let canShowEdit = entry != nil && recoveryGuide == nil && !isLoading
        detailController.showEditButton = canShowEdit && !isEditing
        detailController.isEditing = isEditing
        detailController.canSave = (draft?.isValid ?? false) && !isSaving
        detailController.configureHandlers(
            onEdit: { beginEdit() },
            onCancel: { cancelEdit() },
            onSave: { Task { await saveEdit() } }
        )
    }

    @ViewBuilder
    private func entryContent(_ entry: PassEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                EntryHeroHeader(entryPath: isEditing ? (draft?.entryPath ?? entry.name) : entry.name)

                if isEditing, let draftBinding {
                    editingContent(draftBinding)
                } else {
                    viewingContent(entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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

    private func beginEdit() {
        guard let entry else { return }
        draft = EntryEditDraft.from(entry)
        isEditing = true
        isPasswordRevealed = false
    }

    private func cancelEdit() {
        resetEditState()
    }

    private func resetEditState() {
        isEditing = false
        draft = nil
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
