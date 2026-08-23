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
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("Key", text: binding(for: field.id, keyPath: \.key))
                    .frame(minWidth: 100, alignment: .leading)
                Spacer(minLength: 8)
                TextField("Value", text: binding(for: field.id, keyPath: \.value))
                    .multilineTextAlignment(.trailing)
                Button(role: .destructive) {
                    fields.removeAll { $0.id == field.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
        if PassWebURL.isWebFieldKey(field.key),
           let url = PassWebURL.browserURL(from: field.value) {
            DetailGroupRow(label: field.key, value: field.value, url: url)
        } else {
            DetailGroupRow(
                label: field.key,
                value: field.value,
                onCopy: { onCopy(field.value) }
            )
        }
    }
}
