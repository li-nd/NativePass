import SwiftUI

enum DuplicateTarget: Identifiable, Hashable {
    case entry(String)
    case folder(String)

    var id: String {
        switch self {
        case .entry(let path): return "entry:\(path)"
        case .folder(let path): return "folder:\(path)"
        }
    }

    var sourcePath: String {
        switch self {
        case .entry(let path), .folder(let path): return path
        }
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    var displayName: String {
        sourcePath.split(separator: "/").last.map(String.init) ?? sourcePath
    }
}

struct DuplicatePathSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let target: DuplicateTarget
    var onCompleted: (String) -> Void

    @State private var destinationPath: String = ""
    @State private var didPrepareDestination = false
    @State private var isDuplicating = false
    @State private var errorMessage: String?
    @State private var showFolderContents = false
    @FocusState private var isDestinationFocused: Bool

    private var folderEntries: [String] {
        guard target.isFolder else { return [] }
        return appState.entries(underFolder: target.sourcePath)
    }

    private var trimmedDestination: String {
        destinationPath.trimmingCharacters(
            in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines)
        )
    }

    private var conflictReason: String? {
        let dest = trimmedDestination
        guard !dest.isEmpty else {
            return String(localized: "Enter a destination path.")
        }
        guard dest != target.sourcePath else {
            return String(localized: "Destination must differ from the source.")
        }
        if PassPathDuplication.destinationConflicts(
            dest,
            existingEntries: appState.entries,
            isFolder: target.isFolder
        ) {
            return String(localized: "An entry or folder already exists at this path.")
        }
        return nil
    }

    private var canDuplicate: Bool {
        !isDuplicating && conflictReason == nil
    }

    private var validationMessage: String? {
        if let errorMessage { return errorMessage }
        if didPrepareDestination, !isDuplicating { return conflictReason }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroHeader

                    Text(subtitleText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)

                    DetailGroupCard {
                        DetailGroupRow(
                            label: "Location",
                            value: $destinationPath,
                            isEditing: !isDuplicating
                        )
                        .focused($isDestinationFocused)
                        .onSubmit {
                            if canDuplicate {
                                Task { await performDuplicate() }
                            }
                        }

                        DetailGroupDivider()

                        DetailGroupRow(
                            label: "Original",
                            value: target.sourcePath
                        )
                    }

                    if target.isFolder {
                        folderContentsCard
                    }

                    if let validationMessage {
                        Text(validationMessage)
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
            .navigationTitle(titleText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDuplicating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Duplicate") {
                        Task { await performDuplicate() }
                    }
                    .disabled(!canDuplicate)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .overlay {
                if isDuplicating {
                    ZStack {
                        Color.black.opacity(0.08)
                        ProgressView(String(localized: "Duplicating…"))
                            .padding(16)
                            .background(
                                .regularMaterial,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 460, minHeight: minHeight, idealHeight: idealHeight)
        .onAppear {
            destinationPath = PassPathDuplication.suggestedCopyPath(
                for: target.sourcePath,
                existingEntries: appState.entries,
                isFolder: target.isFolder
            )
            didPrepareDestination = true
            DispatchQueue.main.async {
                isDestinationFocused = true
            }
        }
    }

    private var minHeight: CGFloat {
        target.isFolder ? 440 : 400
    }

    private var idealHeight: CGFloat {
        if target.isFolder, showFolderContents {
            return 560
        }
        return target.isFolder ? 480 : 420
    }

    private var heroHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 72, height: 72)

                if target.isFolder {
                    Image(systemName: "folder.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                } else if let letter = target.displayName.first, letter.isLetter {
                    Text(String(letter).uppercased())
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "key.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }

            Text(target.displayName)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if target.sourcePath.contains("/"), target.sourcePath != target.displayName {
                Text(target.sourcePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var folderContentsCard: some View {
        DetailGroupCard {
            if folderEntries.isEmpty {
                Text(String(localized: "This folder has no password entries."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFolderContents.toggle()
                    }
                } label: {
                    HStack {
                        Text(folderCountLabel)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(showFolderContents ? 90 : 0))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showFolderContents {
                    DetailGroupDivider()
                    ForEach(Array(folderEntries.enumerated()), id: \.element) { index, entry in
                        if index > 0 {
                            DetailGroupDivider()
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                            Text(relativePath(for: entry))
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private var titleText: String {
        target.isFolder
            ? String(localized: "Duplicate Folder")
            : String(localized: "Duplicate Entry")
    }

    private var subtitleText: String {
        target.isFolder
            ? String(localized: "A copy of this folder and everything inside it will be created.")
            : String(localized: "A copy of this password will be created at a new location.")
    }

    private var folderCountLabel: String {
        let count = folderEntries.count
        return count == 1
            ? String(localized: "1 Password")
            : String(localized: "\(count) Passwords")
    }

    private func relativePath(for entry: String) -> String {
        let prefix = target.sourcePath + "/"
        if entry.hasPrefix(prefix) {
            return String(entry.dropFirst(prefix.count))
        }
        return entry
    }

    @MainActor
    private func performDuplicate() async {
        guard canDuplicate else { return }
        isDuplicating = true
        errorMessage = nil
        isDestinationFocused = false

        do {
            try await appState.duplicate(from: target.sourcePath, to: trimmedDestination)
            let destination = trimmedDestination
            if target.isFolder {
                await appState.afterMutation()
                appState.selectedCategory = .folder(destination)
                appState.selectedEntry = nil
            } else {
                await appState.afterMutation(selectEntry: destination)
            }
            onCompleted(destination)
            // Keep isDuplicating true until dismiss finishes — otherwise conflict UI flashes
            // when the store watcher already lists the new destination.
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isDuplicating = false
        }
    }
}
