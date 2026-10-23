import SwiftUI

enum GitRemoteEditorMode: Identifiable, Equatable {
    case add
    case edit(GitRemote)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let remote): "edit:\(remote.name)"
        }
    }

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .add: String(localized: "Add Remote")
        case .edit: String(localized: "Edit Remote")
        }
    }
}

struct GitRemoteEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let mode: GitRemoteEditorMode

    @State private var name: String = "origin"
    @State private var url: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !isSaving
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Name"), text: $name)
                        .disabled(mode.isEditing || isSaving)
                    TextField(String(localized: "URL"), text: $url)
                        .textFieldStyle(.plain)
                        .disabled(isSaving)
                        .onSubmit {
                            if canSave {
                                Task { await save() }
                            }
                        }
                } footer: {
                    Text(String(localized: "Use an HTTPS or SSH URL for your password-store repository."))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 420, height: 260)
        .onAppear {
            switch mode {
            case .add:
                name = "origin"
                url = ""
            case .edit(let remote):
                name = remote.name
                url = remote.primaryURL
            }
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch mode {
            case .add:
                try await appState.gitSync.addRemote(
                    using: appState.git,
                    name: trimmedName,
                    url: trimmedURL
                )
            case .edit:
                try await appState.gitSync.setRemoteURL(
                    using: appState.git,
                    name: trimmedName,
                    url: trimmedURL
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
