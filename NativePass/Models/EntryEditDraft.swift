import Foundation

struct EditableField: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String
    /// When true and key is still the Note label (or empty), serialize as pass freeform lines.
    var isFreeform: Bool

    init(id: UUID = UUID(), key: String, value: String, isFreeform: Bool = false) {
        self.id = id
        self.key = key
        self.value = value
        self.isFreeform = isFreeform
    }

    static var noteLabel: String { String(localized: "Note") }

    var displaysAsFreeform: Bool {
        isFreeform && (key.trimmingCharacters(in: .whitespaces).isEmpty || key == Self.noteLabel)
    }
}

struct EntryEditDraft: Equatable {
    var entryPath: String
    var password: String
    var fields: [EditableField]
    var otpauthLine: String?
    var pendingOTPURI: String = ""

    static func from(_ entry: PassEntry) -> EntryEditDraft {
        EntryEditDraft(
            entryPath: entry.name,
            password: entry.password,
            fields: entry.fields.map {
                EditableField(
                    key: $0.displayKey,
                    value: $0.value,
                    isFreeform: $0.isFreeform
                )
            },
            otpauthLine: entry.otpauthLine,
            pendingOTPURI: ""
        )
    }

    static func empty(suggestedPath: String? = nil) -> EntryEditDraft {
        var path = ""
        if let suggestedPath, !suggestedPath.isEmpty {
            path = suggestedPath + "/"
        }
        return EntryEditDraft(
            entryPath: path,
            password: "",
            fields: [],
            otpauthLine: nil,
            pendingOTPURI: ""
        )
    }

    var trimmedPath: String {
        entryPath.trimmingCharacters(in: .whitespaces)
    }

    var isValid: Bool {
        !trimmedPath.isEmpty && !password.isEmpty
    }

    func toPassFields() -> [PassEntryField] {
        fields.compactMap { field in
            if field.displaysAsFreeform {
                let value = field.value
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return PassEntryField(
                    id: field.id.uuidString,
                    key: "",
                    value: value,
                    isFreeform: true
                )
            }
            let key = field.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { return nil }
            return PassEntryField(
                id: field.id.uuidString,
                key: key,
                value: field.value,
                isFreeform: false
            )
        }
    }

    func toSerializedContent() -> String {
        PassEntrySerializer.serialize(
            password: password,
            fields: toPassFields(),
            otpauthLine: otpauthLine
        )
    }
}
