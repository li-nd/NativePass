import Foundation

enum GitChangeKind: String, Sendable {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case unmerged
    case untracked
    case ignored

    var label: String {
        switch self {
        case .modified: String(localized: "Modified")
        case .added: String(localized: "Added")
        case .deleted: String(localized: "Deleted")
        case .renamed: String(localized: "Renamed")
        case .copied: String(localized: "Copied")
        case .unmerged: String(localized: "Conflict")
        case .untracked: String(localized: "Untracked")
        case .ignored: String(localized: "Ignored")
        }
    }
}

struct GitChangedFile: Identifiable, Sendable, Hashable {
    let path: String
    let kind: GitChangeKind

    var id: String { "\(kind.rawValue):\(path)" }
}

enum GitPorcelainParser {
    /// Parses `git status --porcelain` into human-readable change rows.
    static func parse(_ porcelain: String) -> [GitChangedFile] {
        porcelain
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
    }

    private static func parseLine(_ line: String) -> GitChangedFile? {
        guard line.count >= 3 else { return nil }
        let status = line.prefix(2)
        let pathPart = String(line.dropFirst(3))
        guard !pathPart.isEmpty else { return nil }

        let kind = kind(from: status)
        let path = displayPath(from: pathPart, kind: kind)
        return GitChangedFile(path: path, kind: kind)
    }

    private static func kind(from status: Substring) -> GitChangeKind {
        let chars = Array(status)
        guard chars.count == 2 else { return .modified }
        let index = chars[0]
        let worktree = chars[1]

        if index == "?" || worktree == "?" { return .untracked }
        if index == "!" || worktree == "!" { return .ignored }
        if index == "U" || worktree == "U" || (index == "A" && worktree == "A") {
            return .unmerged
        }

        // Prefer worktree status when present, otherwise index.
        let primary = worktree != " " ? worktree : index
        switch primary {
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "M": return .modified
        default:
            switch index {
            case "A": return .added
            case "D": return .deleted
            case "R": return .renamed
            case "C": return .copied
            default: return .modified
            }
        }
    }

    private static func displayPath(from pathPart: String, kind: GitChangeKind) -> String {
        let unquoted = unquote(pathPart)
        if kind == .renamed || kind == .copied, let arrow = unquoted.range(of: " -> ") {
            let from = String(unquoted[..<arrow.lowerBound])
            let to = String(unquoted[arrow.upperBound...])
            return "\(from) → \(to)"
        }
        return unquoted
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else {
            return value
        }
        let inner = value.dropFirst().dropLast()
        return inner
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\n", with: "\n")
    }
}
