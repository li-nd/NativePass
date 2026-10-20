import SwiftUI

struct LocationDetailSection: View {
    @Binding var entryPath: String

    var body: some View {
        DetailGroupRow(
            label: "Location",
            value: $entryPath,
            isEditing: true
        )
    }
}

struct EditableFieldsSection: View {
    @Binding var fields: [EditableField]
    var showsAddFieldAction: Bool = true

    var body: some View {
        ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
            if index > 0 {
                DetailGroupDivider()
            }
            if field.displaysAsFreeform || field.value.contains("\n") {
                freeformEditor(for: field)
            } else {
                compactEditor(for: field)
            }
        }

        if showsAddFieldAction {
            if !fields.isEmpty {
                DetailGroupDivider()
            }
            DetailGroupActionRow(title: "Add Field") {
                fields.append(EditableField(key: "", value: ""))
            }
        }
    }

    private func compactEditor(for field: EditableField) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            TextField(
                "",
                text: binding(for: field.id, keyPath: \.key),
                prompt: Text("Field").foregroundStyle(.tertiary)
            )
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .frame(minWidth: 100, alignment: .leading)

            Spacer(minLength: 8)

            TextField(
                "",
                text: binding(for: field.id, keyPath: \.value),
                prompt: Text("Value").foregroundStyle(.tertiary)
            )
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .multilineTextAlignment(.trailing)

            deleteButton(for: field.id)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func freeformEditor(for field: EditableField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                TextField(
                    "",
                    text: binding(for: field.id, keyPath: \.key),
                    prompt: Text("Field").foregroundStyle(.tertiary)
                )
                .textFieldStyle(.plain)
                .focusEffectDisabled()
                .frame(maxWidth: 160, alignment: .leading)

                Spacer(minLength: 8)

                deleteButton(for: field.id)
            }

            TextEditor(text: binding(for: field.id, keyPath: \.value))
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .frame(minHeight: freeformEditorHeight(for: field.value), maxHeight: 320)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func deleteButton(for id: UUID) -> some View {
        Button(role: .destructive) {
            fields.removeAll { $0.id == id }
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
    }

    private func freeformEditorHeight(for value: String) -> CGFloat {
        let lines = max(value.split(separator: "\n", omittingEmptySubsequences: false).count, 4)
        return CGFloat(min(lines, 16)) * 18 + 16
    }

    private func binding(for id: UUID, keyPath: WritableKeyPath<EditableField, String>) -> Binding<String> {
        Binding(
            get: {
                fields.first(where: { $0.id == id })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                guard let index = fields.firstIndex(where: { $0.id == id }) else { return }
                fields[index][keyPath: keyPath] = newValue
            }
        )
    }
}

struct EntryFieldsViewSection: View {
    let fields: [PassEntryField]
    var onCopy: (String) -> Void

    var body: some View {
        ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
            if index > 0 {
                DetailGroupDivider()
            }
            fieldRow(for: field)
        }
    }

    @ViewBuilder
    private func fieldRow(for field: PassEntryField) -> some View {
        let label = field.displayKey
        if usesBlockLayout(field) {
            FreeformValueViewer(label: label, value: field.value, onCopy: onCopy)
        } else if !field.isFreeform,
                  PassWebURL.isWebFieldKey(field.key),
                  let url = PassWebURL.browserURL(from: field.value) {
            DetailGroupRow(label: label, value: field.value, url: url)
        } else {
            DetailGroupRow(
                label: label,
                value: field.value,
                onCopy: { onCopy(field.value) }
            )
        }
    }

    private func usesBlockLayout(_ field: PassEntryField) -> Bool {
        field.isFreeform || field.value.contains("\n") || field.value.count > 120
    }
}

/// Read-only multiline value. The Copy button copies the highlighted text, or the whole
/// value when nothing is highlighted; every copy path uses the sensitive clipboard.
private struct FreeformValueViewer: View {
    let label: String
    let value: String
    let onCopy: (String) -> Void

    @State private var selectedText = ""
    @State private var showCopied = false
    @State private var copiedFeedbackTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    copy(selectedText.isEmpty ? value : selectedText)
                } label: {
                    Label(copyButtonTitle, systemImage: showCopied ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)
                .help(selectedText.isEmpty ? "Copy entire note" : "Copy highlighted text")
            }

            SafeSelectableTextView(text: value, selectedText: $selectedText, onCopy: copy)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onDisappear {
            copiedFeedbackTask?.cancel()
        }
    }

    private var copyButtonTitle: LocalizedStringKey {
        if showCopied { return "Copied" }
        return selectedText.isEmpty ? "Copy" : "Copy Selection"
    }

    private func copy(_ text: String) {
        onCopy(text)
        copiedFeedbackTask?.cancel()
        showCopied = true
        copiedFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            showCopied = false
        }
    }
}
