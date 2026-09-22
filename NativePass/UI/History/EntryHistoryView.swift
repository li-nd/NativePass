import SwiftUI

struct EntryHistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let entryName: String
    let currentEntry: PassEntry

    @State private var revisions: [EntryRevision] = []
    @State private var selectedRevisionID: String?
    @State private var loadedRevision: PassEntry?
    @State private var isLoadingList = false
    @State private var isLoadingRevision = false
    @State private var listError: String?
    @State private var revisionError: String?
    @State private var showRaw = false
    @State private var isPasswordRevealed = false
    @State private var isOTPRevealed = false
    @State private var showRestoreConfirm = false
    @State private var isRestoring = false
    @State private var restoreError: String?

    private var selectedRevision: EntryRevision? {
        revisions.first { $0.id == selectedRevisionID }
    }

    private var fieldDiffs: [EntryFieldDiff] {
        guard let loadedRevision else { return [] }
        return EntryDiffBuilder.diff(current: currentEntry, revision: loadedRevision)
    }

    private var hasChanges: Bool {
        fieldDiffs.contains(where: \.hasChange)
    }

    var body: some View {
        NavigationSplitView {
            revisionList
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            revisionDetail
        }
        .navigationTitle(String(localized: "History"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Restore…") {
                    showRestoreConfirm = true
                }
                .disabled(
                    selectedRevision == nil
                        || loadedRevision == nil
                        || !hasChanges
                        || isLoadingRevision
                        || isRestoring
                )
            }
        }
        .sheet(isPresented: $showRestoreConfirm) {
            if let revision = selectedRevision, let loadedRevision {
                EntryRestoreConfirmView(
                    entryName: entryName,
                    revision: revision,
                    diffs: fieldDiffs,
                    isRestoring: isRestoring,
                    onCancel: { showRestoreConfirm = false },
                    onConfirm: {
                        Task { await restore(revision: revision) }
                    }
                )
            }
        }
        .alert("Error", isPresented: .init(
            get: { restoreError != nil },
            set: { if !$0 { restoreError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreError ?? "")
        }
        .task {
            await loadRevisions()
        }
        .onChange(of: selectedRevisionID) { _, _ in
            Task { await loadSelectedRevision() }
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    // MARK: - List

    private var revisionList: some View {
        Group {
            if isLoadingList {
                ProgressView("Loading history…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let listError {
                ContentUnavailableView {
                    Label("Couldn’t Load History", systemImage: "clock.badge.xmark")
                } description: {
                    Text(listError)
                } actions: {
                    Button("Retry") {
                        Task { await loadRevisions() }
                    }
                }
            } else if revisions.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("This entry has no Git commits yet.")
                )
            } else {
                List(revisions, selection: $selectedRevisionID) { revision in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(revision.subject)
                            .font(.body)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            Text(revision.shortHash)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(revision.authoredDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(revision.id)
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var revisionDetail: some View {
        if selectedRevision == nil {
            ContentUnavailableView(
                "Select a Revision",
                systemImage: "clock.arrow.circlepath",
                description: Text("Choose a commit to preview this entry’s past contents.")
            )
        } else if isLoadingRevision {
            ProgressView("Decrypting…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let revisionError {
            ContentUnavailableView {
                Label("Couldn’t Decrypt", systemImage: "lock.trianglebadge.exclamationmark")
            } description: {
                Text(revisionError)
            } actions: {
                Button("Retry") {
                    Task { await loadSelectedRevision() }
                }
            }
        } else if let loadedRevision {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        if let selectedRevision {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedRevision.subject)
                                    .font(.headline)
                                Text("\(selectedRevision.shortHash) · \(selectedRevision.authoredDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(showRaw ? "Form" : "Raw") {
                            showRaw.toggle()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    if showRaw {
                        EntryRawSection(
                            entryName: entryName,
                            rawContent: loadedRevision.rawContent,
                            isEditing: false,
                            maxBodyHeight: 280,
                            editText: .constant(loadedRevision.rawContent),
                            onCopyAll: {
                                appState.clipboard.copy(loadedRevision.rawContent, showToast: false)
                            }
                        )
                    } else {
                        DetailGroupCard {
                            PasswordDetailSection(
                                password: .constant(loadedRevision.password),
                                isEditing: false,
                                isRevealed: $isPasswordRevealed,
                                copyFeedbackScope: "\(entryName)-history-password",
                                onCopy: {
                                    appState.clipboard.copy(loadedRevision.password, showToast: false)
                                },
                                onRevealToggle: { isPasswordRevealed.toggle() },
                                onGenerate: nil
                            )
                        }

                        if loadedRevision.hasOTPMarker {
                            DetailGroupCard {
                                DetailGroupRow(
                                    label: "Code",
                                    value: loadedRevision.otpauthLine ?? "",
                                    isSecret: true,
                                    isRevealed: isOTPRevealed,
                                    onCopy: {
                                        if let line = loadedRevision.otpauthLine {
                                            appState.clipboard.copy(line)
                                        }
                                    },
                                    onRevealToggle: { isOTPRevealed.toggle() }
                                )
                            }
                        }

                        if !loadedRevision.fields.isEmpty {
                            DetailGroupCard {
                                EntryFieldsViewSection(
                                    fields: loadedRevision.fields,
                                    onCopy: { appState.clipboard.copy($0) }
                                )
                            }
                        }

                        if !hasChanges {
                            Text("This revision matches the current entry.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Color.clear
        }
    }

    // MARK: - Actions

    private func loadRevisions() async {
        isLoadingList = true
        listError = nil
        defer { isLoadingList = false }

        do {
            revisions = try await appState.listEntryRevisions(entryName)
            if selectedRevisionID == nil {
                selectedRevisionID = revisions.first?.id
            }
        } catch {
            listError = error.localizedDescription
            revisions = []
        }
    }

    private func loadSelectedRevision() async {
        guard let revision = selectedRevision else {
            loadedRevision = nil
            revisionError = nil
            return
        }

        isLoadingRevision = true
        revisionError = nil
        loadedRevision = nil
        isPasswordRevealed = false
        isOTPRevealed = false
        showRaw = false
        defer { isLoadingRevision = false }

        do {
            loadedRevision = try await appState.loadEntry(entryName, at: revision)
        } catch {
            revisionError = error.localizedDescription
        }
    }

    private func restore(revision: EntryRevision) async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await appState.restoreEntry(entryName, from: revision)
            showRestoreConfirm = false
            dismiss()
        } catch {
            restoreError = error.localizedDescription
        }
    }
}
