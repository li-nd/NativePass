import SwiftUI

struct GitUpstreamEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBranch: String = ""
    @State private var isSaving = false
    @State private var isFetching = false
    @State private var errorMessage: String?

    private var branches: [String] {
        appState.gitSync.remoteBranches
    }

    private var canSave: Bool {
        !isSaving && !selectedBranch.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if branches.isEmpty {
                        Text("No remote branches found. Fetch from a remote first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(String(localized: "Upstream"), selection: $selectedBranch) {
                            ForEach(branches, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.inline)
                        .disabled(isSaving || isFetching)
                    }
                } header: {
                    Text("Remote Branch")
                } footer: {
                    Text("Sets tracking for the current local branch without changing which branch you are on.")
                }

                Section {
                    Button {
                        Task { await fetchRemotes() }
                    } label: {
                        if isFetching {
                            Text("Fetching…")
                        } else {
                            Text("Fetch Remotes")
                        }
                    }
                    .disabled(isFetching || isSaving || appState.gitSync.remotes.isEmpty)

                    if appState.gitSync.status?.hasUpstream == true {
                        Button("Clear Upstream", role: .destructive) {
                            Task { await clearUpstream() }
                        }
                        .disabled(isSaving || isFetching)
                    }
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
            .navigationTitle(String(localized: "Change Upstream"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving || isFetching)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isFetching)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 420, height: 420)
        .onAppear {
            let current = appState.gitSync.status?.upstream ?? ""
            if branches.contains(current) {
                selectedBranch = current
            } else if let preferred = preferredDefaultBranch {
                selectedBranch = preferred
            } else {
                selectedBranch = branches.first ?? ""
            }
        }
    }

    private var preferredDefaultBranch: String? {
        let remote = appState.gitSync.preferredUpstreamRemoteName ?? "origin"
        let local = appState.gitSync.status?.branch
        if let local {
            let candidate = "\(remote)/\(local)"
            if branches.contains(candidate) { return candidate }
        }
        let main = "\(remote)/main"
        if branches.contains(main) { return main }
        let master = "\(remote)/master"
        if branches.contains(master) { return master }
        return nil
    }

    @MainActor
    private func fetchRemotes() async {
        isFetching = true
        errorMessage = nil
        defer { isFetching = false }
        await appState.gitSync.fetch(using: appState.git)
        if let err = appState.gitSync.lastError {
            errorMessage = err
        }
        if selectedBranch.isEmpty || !branches.contains(selectedBranch) {
            selectedBranch = preferredDefaultBranch ?? branches.first ?? ""
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await appState.gitSync.setUpstream(using: appState.git, remoteBranch: selectedBranch)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearUpstream() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await appState.gitSync.unsetUpstream(using: appState.git)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
