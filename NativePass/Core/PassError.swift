import Foundation

enum PassError: Error, LocalizedError {
    case binaryNotFound(String)
    case commandFailed(exitCode: Int32, stderr: String)
    case timedOut(command: String)
    case storeNotInitialized
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return String(localized: "\(name) was not found on this system.")
        case .commandFailed(_, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? String(localized: "Pass command failed.") : trimmed
        case .timedOut(let command):
            return String(localized: "Command timed out: \(command)")
        case .storeNotInitialized:
            return String(localized: "Password store is not initialized. Run `pass init` first.")
        case .parseFailed(let detail):
            return String(localized: "Failed to parse pass output: \(detail)")
        }
    }
}

struct PassCLIResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}
