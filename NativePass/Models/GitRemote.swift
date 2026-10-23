import Foundation

struct GitRemote: Identifiable, Hashable, Sendable {
    let name: String
    var fetchURL: String
    var pushURL: String

    var id: String { name }

    var displayURL: String {
        fetchURL.isEmpty ? pushURL : fetchURL
    }

    /// Prefer a single URL when fetch and push match.
    var primaryURL: String {
        if !fetchURL.isEmpty { return fetchURL }
        return pushURL
    }
}

enum GitRemoteParser {
    /// Parses `git remote -v` output into unique remotes.
    static func parse(_ output: String) -> [GitRemote] {
        var fetchURLs: [String: String] = [:]
        var pushURLs: [String: String] = [:]

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // name<TAB>url (fetch|push)
            let parts = line.split(whereSeparator: { $0 == "\t" || $0 == " " })
                .map(String.init)
                .filter { !$0.isEmpty }
            guard parts.count >= 3 else { continue }

            let name = parts[0]
            let url = parts[1]
            let kind = parts[2].trimmingCharacters(in: CharacterSet(charactersIn: "()"))

            switch kind {
            case "fetch":
                fetchURLs[name] = url
            case "push":
                pushURLs[name] = url
            default:
                if fetchURLs[name] == nil {
                    fetchURLs[name] = url
                }
            }
        }

        let names = Set(fetchURLs.keys).union(pushURLs.keys).sorted()
        return names.map { name in
            GitRemote(
                name: name,
                fetchURL: fetchURLs[name] ?? "",
                pushURL: pushURLs[name] ?? fetchURLs[name] ?? ""
            )
        }
    }
}
