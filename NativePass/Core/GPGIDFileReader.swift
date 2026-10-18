import Foundation

enum GPGIDFileReader {
    static func readIDs(from fileURL: URL) -> [String] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return parseIDs(from: contents)
    }

    static func parseIDs(from contents: String) -> [String] {
        contents
            .split(separator: "\n")
            .map { $0.split(separator: "#", maxSplits: 1).first.map(String.init) ?? "" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
