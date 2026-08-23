import Foundation

enum PassStoreScanner {
    static func listEntries(in storeDirectory: URL) -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: storeDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let storePrefix = storeDirectory.path + "/"
        var entries: [String] = []

        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            if path.contains("/.git/") || path.contains("/.extensions/") {
                continue
            }
            guard fileURL.pathExtension == "gpg" else { continue }
            var name = fileURL.deletingPathExtension().path
            if name.hasPrefix(storePrefix) {
                name = String(name.dropFirst(storePrefix.count))
            }
            guard !name.isEmpty else { continue }
            entries.append(name)
        }

        return entries.sorted()
    }
}
