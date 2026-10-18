import SwiftUI

enum StoreItemInfoTarget: Identifiable, Equatable {
    case folder(String)
    case entry(String)

    var id: String {
        switch self {
        case .folder(let path): "folder:\(path)"
        case .entry(let name): "entry:\(name)"
        }
    }

    var title: String {
        switch self {
        case .folder(let path):
            return path.split(separator: "/").last.map(String.init) ?? path
        case .entry(let name):
            return PassFolderNode.entryDisplayName(name)
        }
    }
}

struct StoreItemInfoSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let target: StoreItemInfoTarget

    private var policy: GPGRecipientPolicy {
        switch target {
        case .folder(let path):
            return appState.encryptionMap.effective(forFolder: path)
        case .entry(let name):
            return appState.encryptionMap.effective(forEntry: name)
        }
    }

    private var pathLabel: String {
        switch target {
        case .folder(let path): path
        case .entry(let name): name
        }
    }

    private var entryCount: Int? {
        guard case .folder(let path) = target else { return nil }
        return appState.entries(underFolder: path).count
    }

    private var modified: Date? {
        guard case .entry(let name) = target else { return nil }
        return appState.entryModificationDate(for: name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(targetTitle)
                .font(.headline)

            LabeledContent("Path") {
                Text(pathLabel)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }

            if let entryCount {
                LabeledContent("Entries", value: "\(entryCount)")
            }

            if let modified {
                LabeledContent("Modified") {
                    Text(modified, format: .dateTime)
                        .font(.callout)
                }
            }

            Divider()

            Text("Encryption")
                .font(.subheadline.weight(.semibold))

            if policy.gpgIDs.isEmpty {
                Text("No recipients configured.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(policy.gpgIDs, id: \.self) { id in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.displayLabel(forGPGID: id))
                        Text(id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Text(sourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360, idealWidth: 420)
    }

    private var targetTitle: String {
        switch target {
        case .folder:
            return String(localized: "Folder Info")
        case .entry:
            return String(localized: "Entry Info")
        }
    }

    private var sourceDescription: String {
        if policy.sourcePath.isEmpty {
            return policy.isInherited
                ? String(localized: "From store root (.gpg-id)")
                : String(localized: "Store root (.gpg-id)")
        }
        if policy.isInherited {
            return String(localized: "Inherited from \(policy.sourcePath)/.gpg-id")
        }
        return String(localized: "Local \(policy.sourcePath)/.gpg-id")
    }
}

struct FolderDeleteConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss

    let folderPath: String
    let entries: [String]
    var onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete \"\(folderPath)\"?")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text(warningText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if entries.isEmpty {
                Text("The folder has no password entries (it may only contain a .gpg-id).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Will be deleted:")
                    .font(.subheadline.weight(.semibold))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(entries, id: \.self) { entry in
                            Text(entry)
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 220)
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Delete Folder", role: .destructive) {
                    onConfirm()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var warningText: String {
        let count = entries.count
        let items = count == 1
            ? String(localized: "1 entry")
            : String(localized: "\(count) entries")
        return String(
            localized: "This permanently removes the folder and \(items) from the password store."
        )
    }
}
