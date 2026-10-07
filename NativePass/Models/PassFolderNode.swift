import Foundation

struct PassFolderNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var subfolders: [PassFolderNode]
    /// True when this folder has its own `.gpg-id` that differs from the store root.
    var hasDistinctEncryption: Bool

    var isExpandable: Bool {
        !subfolders.isEmpty
    }

    static func buildFolderTree(
        from allEntries: [String],
        ensuringFolders: [String] = [],
        distinctEncryptionFolders: Set<String> = []
    ) -> [PassFolderNode] {
        var roots: [PassFolderNode] = []
        for entry in allEntries where entry.contains("/") {
            let parts = entry.split(separator: "/").map(String.init)
            guard parts.count >= 2 else { continue }
            insertFolderParts(
                Array(parts.dropLast()),
                parentPath: "",
                into: &roots,
                distinctEncryptionFolders: distinctEncryptionFolders
            )
        }
        for folder in ensuringFolders {
            let parts = StoreEncryptionMap.normalizeRelativePath(folder)
                .split(separator: "/")
                .map(String.init)
            guard !parts.isEmpty else { continue }
            insertFolderParts(
                parts,
                parentPath: "",
                into: &roots,
                distinctEncryptionFolders: distinctEncryptionFolders
            )
        }
        sortTree(&roots)
        return roots
    }

    static func entries(
        for selection: SidebarSelection,
        from allEntries: [String],
        metadataCache: EntryMetadataCache
    ) -> [String] {
        switch selection {
        case .all:
            return allEntries.sorted()
        case .folder(let path):
            let prefix = path + "/"
            return allEntries
                .filter { $0 == path || $0.hasPrefix(prefix) }
                .sorted()
        case .verificationCodes:
            return allEntries
                .filter { metadataCache.metadata(for: $0)?.hasOTP == true }
                .sorted()
        }
    }

    static func entryDisplayName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    // MARK: - Private

    private static func insertFolderParts(
        _ parts: [String],
        parentPath: String,
        into nodes: inout [PassFolderNode],
        distinctEncryptionFolders: Set<String>
    ) {
        guard let head = parts.first else { return }
        let folderPath = parentPath.isEmpty ? head : "\(parentPath)/\(head)"
        let index = findOrCreateSubfolder(
            named: head,
            id: folderPath,
            hasDistinctEncryption: distinctEncryptionFolders.contains(folderPath),
            in: &nodes
        )
        if parts.count > 1 {
            insertFolderParts(
                Array(parts.dropFirst()),
                parentPath: folderPath,
                into: &nodes[index].subfolders,
                distinctEncryptionFolders: distinctEncryptionFolders
            )
        }
    }

    private static func findOrCreateSubfolder(
        named name: String,
        id: String,
        hasDistinctEncryption: Bool,
        in nodes: inout [PassFolderNode]
    ) -> Int {
        if let index = nodes.firstIndex(where: { $0.name == name }) {
            if hasDistinctEncryption {
                nodes[index].hasDistinctEncryption = true
            }
            return index
        }
        nodes.append(
            PassFolderNode(
                id: id,
                name: name,
                subfolders: [],
                hasDistinctEncryption: hasDistinctEncryption
            )
        )
        return nodes.count - 1
    }

    private static func sortTree(_ nodes: inout [PassFolderNode]) {
        for index in nodes.indices {
            sortTree(&nodes[index].subfolders)
        }
        nodes.sort { $0.name < $1.name }
    }
}
