import Foundation

struct PassFolderNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var subfolders: [PassFolderNode]

    var isExpandable: Bool {
        !subfolders.isEmpty
    }

    static func buildFolderTree(from allEntries: [String]) -> [PassFolderNode] {
        var roots: [PassFolderNode] = []
        for entry in allEntries where entry.contains("/") {
            let parts = entry.split(separator: "/").map(String.init)
            guard parts.count >= 2 else { continue }
            insertFolderParts(Array(parts.dropLast()), parentPath: "", into: &roots)
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
        into nodes: inout [PassFolderNode]
    ) {
        guard let head = parts.first else { return }
        let folderPath = parentPath.isEmpty ? head : "\(parentPath)/\(head)"
        let index = findOrCreateSubfolder(named: head, id: folderPath, in: &nodes)
        if parts.count > 1 {
            insertFolderParts(Array(parts.dropFirst()), parentPath: folderPath, into: &nodes[index].subfolders)
        }
    }

    private static func findOrCreateSubfolder(
        named name: String,
        id: String,
        in nodes: inout [PassFolderNode]
    ) -> Int {
        if let index = nodes.firstIndex(where: { $0.name == name }) {
            return index
        }
        nodes.append(PassFolderNode(id: id, name: name, subfolders: []))
        return nodes.count - 1
    }

    private static func sortTree(_ nodes: inout [PassFolderNode]) {
        for index in nodes.indices {
            sortTree(&nodes[index].subfolders)
        }
        nodes.sort { $0.name < $1.name }
    }
}
