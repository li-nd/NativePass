import Foundation

enum PassWebURL {
    private static let webFieldKeys: Set<String> = ["url", "website", "uri"]

    static func isWebFieldKey(_ key: String) -> Bool {
        webFieldKeys.contains(key.lowercased())
    }

    static func browserURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("mailto:") || lowered.hasPrefix("tel:") {
            return URL(string: trimmed)
        }

        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            return URL(string: trimmed)
        }

        if trimmed.hasPrefix("//") {
            return URL(string: "https:\(trimmed)")
        }

        guard !trimmed.contains(where: \.isWhitespace) else { return nil }

        return URL(string: "https://\(trimmed)")
    }
}
