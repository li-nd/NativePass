import Foundation

struct PassEntryField: Identifiable, Hashable, Sendable {
    let id: String
    /// Empty when `isFreeform` — not written as `key: value` on disk.
    let key: String
    let value: String
    /// Pass freeform body lines (no `key:` prefix), shown as “Note” in the UI.
    let isFreeform: Bool

    init(id: String, key: String, value: String, isFreeform: Bool = false) {
        self.id = id
        self.key = key
        self.value = value
        self.isFreeform = isFreeform
    }

    /// Label for Form / detail rows (not written to the pass file for freeform).
    var displayKey: String {
        isFreeform ? String(localized: "Note") : key
    }
}

struct PassEntry: Identifiable, Hashable, Sendable {
    let name: String
    /// Exact decrypted file contents from `pass show` (preserves newlines / freeform text).
    let rawContent: String
    let password: String
    let fields: [PassEntryField]
    let hasOTPMarker: Bool
    let otpauthLine: String?

    var id: String { name }
}

enum PassEntryParser {
    static func parse(name: String, content: String) -> PassEntry {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let password = lines.first ?? ""
        var fields: [PassEntryField] = []
        var otpauthLine: String?
        var freeformLines: [String] = []

        func flushFreeform() {
            guard !freeformLines.isEmpty else { return }
            // Drop a trailing run of blank lines that only padded before EOF / next key.
            while freeformLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                freeformLines.removeLast()
            }
            guard !freeformLines.isEmpty else { return }
            let value = freeformLines.joined(separator: "\n")
            fields.append(
                PassEntryField(
                    id: "freeform-\(fields.count)",
                    key: "",
                    value: value,
                    isFreeform: true
                )
            )
            freeformLines = []
        }

        for line in lines.dropFirst() {
            if line.hasPrefix("otpauth://") {
                flushFreeform()
                otpauthLine = line
                continue
            }
            if let keyed = parseKeyedLine(line) {
                flushFreeform()
                fields.append(
                    PassEntryField(
                        id: "field-\(fields.count)-\(keyed.key)",
                        key: keyed.key,
                        value: keyed.value,
                        isFreeform: false
                    )
                )
            } else {
                freeformLines.append(line)
            }
        }
        flushFreeform()

        return PassEntry(
            name: name,
            rawContent: content,
            password: password,
            fields: fields,
            hasOTPMarker: otpauthLine != nil,
            otpauthLine: otpauthLine
        )
    }

    /// `key: value` only when the key is non-empty; otherwise treat as freeform (pass-compatible).
    private static func parseKeyedLine(_ line: String) -> (key: String, value: String)? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        // Avoid treating PEM / prose with incidental colons mid-line as keys when…
        // Actually pass GUIs traditionally split on first `:`. Keep that for real metadata.
        let valueStart = line.index(after: colonIndex)
        let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
        return (key, value)
    }
}

enum PassEntrySerializer {
    static func serialize(entry: PassEntry) -> String {
        serialize(
            password: entry.password,
            fields: entry.fields,
            otpauthLine: entry.otpauthLine
        )
    }

    static func serialize(
        password: String,
        fields: [PassEntryField],
        otpauthLine: String?
    ) -> String {
        var lines = [password]
        for field in fields {
            if field.isFreeform {
                let body = field.value.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                lines.append(contentsOf: body)
            } else {
                lines.append("\(field.key): \(field.value)")
            }
        }
        if let otpauthLine {
            lines.append(otpauthLine)
        }
        return lines.joined(separator: "\n")
    }
}
