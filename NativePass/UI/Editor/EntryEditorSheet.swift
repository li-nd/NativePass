import SwiftUI

enum EntryEditorMode: Identifiable {
    case create(suggestedPath: String?)

    var id: String {
        switch self {
        case .create(let path): return "create-\(path ?? "")"
        }
    }
}

struct EntryEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let mode: EntryEditorMode
    let onSaved: (String) -> Void

    @State private var draft = EntryEditDraft.empty()
    @State private var isPasswordRevealed = false
    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EntryHeroHeader(entryPath: draft.entryPath)

                    DetailGroupCard {
                        LocationDetailSection(entryPath: $draft.entryPath)

                        DetailGroupDivider()

                        PasswordDetailSection(
                            password: $draft.password,
                            isEditing: true,
                            isRevealed: $isPasswordRevealed,
                            isGenerating: isGenerating,
                            onCopy: { appState.clipboard.copy(draft.password, showToast: false) },
                            onRevealToggle: { isPasswordRevealed.toggle() },
                            onGenerate: generatePassword
                        )
                    }

                    VerificationCodeDetailSection(
                        entryName: draft.trimmedPath.isEmpty ? "new-entry" : draft.trimmedPath,
                        hasOTPMarker: draft.otpauthLine != nil,
                        isEditing: true,
                        otpauthLine: $draft.otpauthLine,
                        pendingOTPInput: $draft.pendingOTPURI
                    )

                    DetailGroupCard {
                        if !draft.fields.isEmpty {
                            EditableFieldsSection(fields: $draft.fields)
                        } else {
                            DetailGroupActionRow(title: "Add Field") {
                                draft.fields.append(EditableField(key: "", value: ""))
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !draft.isValid)
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 460, minHeight: 480, idealHeight: 520)
        .onAppear { populateFromMode() }
    }

    private func populateFromMode() {
        switch mode {
        case .create(let suggestedPath):
            draft = EntryEditDraft.empty(suggestedPath: suggestedPath)
        }
    }

    private func generatePassword() {
        isGenerating = true
        defer { isGenerating = false }
        do {
            draft.password = try PasswordGenerator.generate(
                length: AppPreferences.generatedPasswordLength
            )
            isPasswordRevealed = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        let name = draft.trimmedPath
        guard draft.isValid else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let pendingOTP = draft.pendingOTPURI.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var otpLine = draft.otpauthLine
            if otpLine == nil, !pendingOTP.isEmpty {
                otpLine = try TOTPGenerator.makeOTPAuthURI(fromSetupInput: pendingOTP, account: name)
            }
            let finalContent = PassEntrySerializer.serialize(
                password: draft.password,
                fields: draft.toPassFields(),
                otpauthLine: otpLine
            )
            try await appState.saveEntry(name, content: finalContent, force: false)

            await appState.afterMutation(selectEntry: name)
            onSaved(name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
