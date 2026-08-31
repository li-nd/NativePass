import Foundation

struct PassEntryField: Identifiable, Hashable, Sendable {
    let id: String
    let key: String
    let value: String
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

        for line in lines.dropFirst() {
            if line.hasPrefix("otpauth://") {
                otpauthLine = line
                continue
            }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueStart = line.index(after: colonIndex)
                let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    fields.append(PassEntryField(id: key, key: key, value: value))
                }
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                fields.append(PassEntryField(id: "line-\(fields.count)", key: String(localized: "Note"), value: line))
            }
        }

        return PassEntry(
            name: name,
            rawContent: content,
            password: password,
            fields: fields,
            hasOTPMarker: otpauthLine != nil,
            otpauthLine: otpauthLine
        )
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
            lines.append("\(field.key): \(field.value)")
        }
        if let otpauthLine {
            lines.append(otpauthLine)
        }
        return lines.joined(separator: "\n")
    }
}
