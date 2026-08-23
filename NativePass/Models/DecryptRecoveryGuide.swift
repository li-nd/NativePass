import Foundation

struct RecoveryStep: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let detail: String?
    let command: String?

    init(title: String, detail: String? = nil, command: String? = nil) {
        self.title = title
        self.detail = detail
        self.command = command
    }
}

struct DecryptRecoveryGuide: Sendable {
    enum Kind: Sendable {
        case pinentryNotConfigured
        case keyLocked
        case keyMissing
        case userCancelled
        case agentUnavailable
        case unknown
    }

    let kind: Kind
    let title: String
    let explanation: String
    let steps: [RecoveryStep]
    let rawError: String
    let gpgRecipientIDs: [String]

    var shortSummary: String { title }
}
