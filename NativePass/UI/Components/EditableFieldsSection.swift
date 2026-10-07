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
            freeformViewer(label: label, value: field.value, onCopy: { onCopy(field.value) })
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

    private func freeformViewer(label: String, value: String, onCopy: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CopyableValueText(
                value: value,
                isMonospaced: true,
                lineLimit: nil,
                textAlignment: .leading,
                onCopy: onCopy
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
