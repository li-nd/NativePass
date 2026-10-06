import Foundation

struct EntryRevision: Identifiable, Hashable, Sendable {
    var id: String { commitHash }

    let commitHash: String
    let shortHash: String
    let authoredDate: Date
    let subject: String
    /// Path of the `.gpg` file inside the store at this commit (may differ after renames).
    let relativeGPGPath: String
}

enum EntryFieldDiffKind: String, Sendable {
    case unchanged
    case modified
    case added
    case removed
}

struct EntryFieldDiff: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let currentValue: String?
    let revisionValue: String?
    let kind: EntryFieldDiffKind
    let isSecret: Bool

    var hasChange: Bool { kind != .unchanged }
}

enum EntryDiffBuilder {
    static func diff(current: PassEntry, revision: PassEntry) -> [EntryFieldDiff] {
        var rows: [EntryFieldDiff] = []

        rows.append(
            makeDiff(
                id: "password",
                label: String(localized: "Password"),
                current: current.password,
                revision: revision.password,
                isSecret: true
            )
        )

        let currentKeys = current.fields.map(\.key)
        let revisionKeys = revision.fields.map(\.key)
        var seen = Set<String>()
        for key in currentKeys + revisionKeys {
            let lowered = key.lowercased()
            guard seen.insert(lowered).inserted else { continue }
            let currentValue = current.fields.first { $0.key.lowercased() == lowered }?.value
            let revisionValue = revision.fields.first { $0.key.lowercased() == lowered }?.value
            let label = current.fields.first { $0.key.lowercased() == lowered }?.key
                ?? revision.fields.first { $0.key.lowercased() == lowered }?.key
                ?? key
            rows.append(
                makeDiff(
                    id: "field-\(lowered)",
                    label: label,
                    current: currentValue,
                    revision: revisionValue,
                    isSecret: false
                )
            )
        }

        rows.append(
            makeDiff(
                id: "otp",
                label: String(localized: "Code"),
                current: current.otpauthLine,
                revision: revision.otpauthLine,
                isSecret: true
            )
        )

        return rows
    }

    private static func makeDiff(
        id: String,
        label: String,
        current: String?,
        revision: String?,
        isSecret: Bool
    ) -> EntryFieldDiff {
        let currentNorm = normalize(current)
        let revisionNorm = normalize(revision)
        let kind: EntryFieldDiffKind
        switch (currentNorm, revisionNorm) {
        case (nil, nil):
            kind = .unchanged
        case (nil, .some):
            kind = .added
        case (.some, nil):
            kind = .removed
        case let (c?, r?) where c == r:
            kind = .unchanged
        default:
            kind = .modified
        }
        return EntryFieldDiff(
            id: id,
            label: label,
            currentValue: currentNorm,
            revisionValue: revisionNorm,
            kind: kind,
            isSecret: isSecret
        )
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }
}
