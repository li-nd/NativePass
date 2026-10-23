import Foundation

enum PassPathDuplication {
    /// Suggests `path-copy`, then `path-copy-2`, … that does not collide with existing entries.
    static func suggestedCopyPath(
        for path: String,
        existingEntries: [String],
        isFolder: Bool
    ) -> String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        guard !trimmed.isEmpty else { return "copy" }

        let first = "\(trimmed)-copy"
        if !destinationConflicts(first, existingEntries: existingEntries, isFolder: isFolder) {
            return first
        }

        var index = 2
        while true {
            let candidate = "\(trimmed)-copy-\(index)"
            if !destinationConflicts(candidate, existingEntries: existingEntries, isFolder: isFolder) {
                return candidate
            }
            index += 1
        }
    }

    static func destinationConflicts(
        _ destination: String,
        existingEntries: [String],
        isFolder: Bool
    ) -> Bool {
        let dest = destination.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        guard !dest.isEmpty else { return true }

        if isFolder {
            let prefix = dest + "/"
            return existingEntries.contains { $0 == dest || $0.hasPrefix(prefix) }
        }
        return existingEntries.contains(dest)
    }
}
