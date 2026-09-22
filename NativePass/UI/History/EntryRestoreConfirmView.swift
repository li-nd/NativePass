import SwiftUI

struct EntryRestoreConfirmView: View {
    let entryName: String
    let revision: EntryRevision
    let diffs: [EntryFieldDiff]
    let isRestoring: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var revealSecrets = false

    private var changedDiffs: [EntryFieldDiff] {
        diffs.filter(\.hasChange)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(
                    String(
                        localized: "Overwrite “\(entryName)” with the version from \(revision.shortHash)? This creates a new Git commit with the restored contents."
                    )
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                HStack {
                    Spacer()
                    Toggle("Show secret values", isOn: $revealSecrets)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        headerRow
                        Divider()
                        ForEach(changedDiffs) { diff in
                            diffRow(diff)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                if changedDiffs.isEmpty {
                    Text("No differences from the current entry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .navigationTitle(String(localized: "Restore Revision"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isRestoring)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore", role: .destructive) {
                        onConfirm()
                    }
                    .disabled(isRestoring || changedDiffs.isEmpty)
                }
            }
            .overlay {
                if isRestoring {
                    ZStack {
                        Color.black.opacity(0.08)
                        ProgressView("Restoring…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 360, idealHeight: 420)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Field")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text("Current")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(revision.shortHash)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func diffRow(_ diff: EntryFieldDiff) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: kindIcon(diff.kind))
                    .foregroundStyle(kindColor(diff.kind))
                    .font(.caption)
                Text(diff.label)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
            }
            .frame(width: 120, alignment: .leading)

            valueCell(diff.currentValue, kind: diff.kind, side: .current, isSecret: diff.isSecret)
                .frame(maxWidth: .infinity, alignment: .leading)

            valueCell(diff.revisionValue, kind: diff.kind, side: .revision, isSecret: diff.isSecret)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(kindBackground(diff.kind))
    }

    private enum Side { case current, revision }

    @ViewBuilder
    private func valueCell(
        _ value: String?,
        kind: EntryFieldDiffKind,
        side: Side,
        isSecret: Bool
    ) -> some View {
        let display: String = {
            guard let value else { return "—" }
            if isSecret && !revealSecrets {
                return String(repeating: "•", count: min(max(value.count, 8), 16))
            }
            return value
        }()

        Text(display)
            .font(.callout.monospaced())
            .foregroundStyle(valueForeground(kind: kind, side: side, empty: value == nil))
            .textSelection(.enabled)
            .lineLimit(4)
    }

    private func kindIcon(_ kind: EntryFieldDiffKind) -> String {
        switch kind {
        case .unchanged: "equal"
        case .modified: "pencil"
        case .added: "plus"
        case .removed: "minus"
        }
    }

    private func kindColor(_ kind: EntryFieldDiffKind) -> Color {
        switch kind {
        case .unchanged: .secondary
        case .modified: .orange
        case .added: .green
        case .removed: .red
        }
    }

    private func kindBackground(_ kind: EntryFieldDiffKind) -> Color {
        switch kind {
        case .unchanged: .clear
        case .modified: Color.orange.opacity(0.06)
        case .added: Color.green.opacity(0.06)
        case .removed: Color.red.opacity(0.06)
        }
    }

    private func valueForeground(kind: EntryFieldDiffKind, side: Side, empty: Bool) -> Color {
        if empty { return .secondary }
        switch kind {
        case .unchanged:
            return .primary
        case .modified:
            return side == .current ? .red : .green
        case .added:
            return side == .revision ? .green : .secondary
        case .removed:
            return side == .current ? .red : .secondary
        }
    }
}
