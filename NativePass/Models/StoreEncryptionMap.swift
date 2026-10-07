import Foundation

struct GPGRecipientPolicy: Sendable, Equatable {
    /// Relative folder path of the selection; empty string = store root.
    let folderPath: String
    let gpgIDs: [String]
    /// True when recipients come from an ancestor `.gpg-id`, not a local file on this folder.
    let isInherited: Bool
    /// Relative path of the `.gpg-id` that applies (`""` for store root).
    let sourcePath: String

    var hasRecipients: Bool { !gpgIDs.isEmpty }
}

struct StoreEncryptionMap: Sendable, Equatable {
    let rootIDs: [String]
    /// Folders that define their own `.gpg-id` (non-root), keyed by relative path.
    let localPolicies: [String: [String]]

    static let empty = StoreEncryptionMap(rootIDs: [], localPolicies: [:])

    var foldersWithLocalPolicy: [String] {
        localPolicies.keys.sorted()
    }

    /// Effective recipients for a password entry path (`Folder/name`).
    func effective(forEntry entryPath: String) -> GPGRecipientPolicy {
        let normalized = Self.normalizeRelativePath(entryPath)
        let parts = normalized.split(separator: "/").map(String.init)
        let folderPath = parts.count > 1 ? parts.dropLast().joined(separator: "/") : ""
        return effective(forFolder: folderPath)
    }

    /// Effective recipients for a sidebar folder path (`""` = entire store / All).
    func effective(forFolder folderPath: String) -> GPGRecipientPolicy {
        let normalized = Self.normalizeRelativePath(folderPath)
        let candidates = Self.folderAndAncestors(normalized)

        for folder in candidates {
            if folder.isEmpty {
                break
            }
            if let ids = localPolicies[folder] {
                return GPGRecipientPolicy(
                    folderPath: normalized,
                    gpgIDs: ids,
                    isInherited: folder != normalized,
                    sourcePath: folder
                )
            }
        }

        return GPGRecipientPolicy(
            folderPath: normalized,
            gpgIDs: rootIDs,
            isInherited: !normalized.isEmpty,
            sourcePath: ""
        )
    }

    func hasDistinctLocalPolicy(atFolderPath path: String) -> Bool {
        let normalized = Self.normalizeRelativePath(path)
        guard let local = localPolicies[normalized] else { return false }
        return local != rootIDs
    }

    static func scan(storeDirectory: URL) -> StoreEncryptionMap {
        let fileManager = FileManager.default
        let rootFile = storeDirectory.appendingPathComponent(".gpg-id")
        let rootIDs = GPGIDFileReader.readIDs(from: rootFile)

        var local: [String: [String]] = [:]
        guard let enumerator = fileManager.enumerator(
            at: storeDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return StoreEncryptionMap(rootIDs: rootIDs, localPolicies: [:])
        }

        let storePrefix = storeDirectory.path + "/"
        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            if path.contains("/.git/") || path.contains("/.extensions/") {
                continue
            }
            guard fileURL.lastPathComponent == ".gpg-id" else { continue }
            let parent = fileURL.deletingLastPathComponent().standardizedFileURL
            let store = storeDirectory.standardizedFileURL
            if parent.path == store.path {
                continue
            }
            var relative = parent.path
            if relative.hasPrefix(storePrefix) {
                relative = String(relative.dropFirst(storePrefix.count))
            } else if relative.hasPrefix(store.path + "/") {
                relative = String(relative.dropFirst(store.path.count + 1))
            }
            relative = normalizeRelativePath(relative)
            guard !relative.isEmpty else { continue }
            let ids = GPGIDFileReader.readIDs(from: fileURL)
            if !ids.isEmpty {
                local[relative] = ids
            }
        }

        return StoreEncryptionMap(rootIDs: rootIDs, localPolicies: local)
    }

    static func normalizeRelativePath(_ path: String) -> String {
        var result = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        while result.contains("//") {
            result = result.replacingOccurrences(of: "//", with: "/")
        }
        return result
    }

    /// `Shared/Nested` → [`Shared/Nested`, `Shared`]
    private static func folderAndAncestors(_ folderPath: String) -> [String] {
        let normalized = normalizeRelativePath(folderPath)
        guard !normalized.isEmpty else { return [] }
        var parts = normalized.split(separator: "/").map(String.init)
        var result: [String] = []
        while !parts.isEmpty {
            result.append(parts.joined(separator: "/"))
            parts.removeLast()
        }
        return result
    }
}
