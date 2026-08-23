import Foundation

enum PassVersionParser {
    private static let passVersionPattern = /v([0-9]+(?:\.[0-9]+)*)/

    static func parsePassVersion(from text: String) -> String? {
        for line in text.split(separator: "\n") {
            if let match = line.firstMatch(of: passVersionPattern) {
                return String(match.1)
            }
        }
        return nil
    }

    static func parseGPGVersion(from output: String) -> String? {
        guard let firstLine = output.split(separator: "\n").first else { return nil }
        let parts = firstLine.split(separator: " ")
        return parts.last.map(String.init)
    }

    static func parseSystemExtensionDir(from passScript: String) -> String? {
        let pattern = /SYSTEM_EXTENSION_DIR="([^"]+)"/
        guard let match = passScript.firstMatch(of: pattern) else { return nil }
        return String(match.1)
    }

    static func parsePinentryProgram(from gpgAgentConf: String) -> String? {
        for line in gpgAgentConf.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("pinentry-program") {
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
