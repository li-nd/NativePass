import Foundation

struct EditableField: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
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
            fields: entry.fields.map { EditableField(key: $0.key, value: $0.value) },
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
        fields
            .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { PassEntryField(id: $0.key, key: $0.key, value: $0.value) }
    }

    func toSerializedContent() -> String {
        PassEntrySerializer.serialize(
            password: password,
            fields: toPassFields(),
            otpauthLine: otpauthLine
        )
    }
}
