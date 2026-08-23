import Foundation

enum PluginSource: Sendable, Equatable {
    case system(directory: URL)
    case user(directory: URL)
}

enum PluginActivationState: Sendable, Equatable {
    case notFound
    case installed
    case foundButInactive(reason: String)
    case active(version: String?)
    case degraded(version: String?, warnings: [String])

    var isUsable: Bool {
        switch self {
        case .installed, .active, .degraded:
            return true
        case .notFound, .foundButInactive:
            return false
        }
    }

    var inactiveReason: String? {
        if case .foundButInactive(let reason) = self {
            return reason
        }
        return nil
    }
}

struct PassPluginInfo: Identifiable, Sendable, Equatable {
    let id: String
    let command: String
    let displayName: String
    let homepage: URL?
    let filePath: URL?
    let source: PluginSource?
    let state: PluginActivationState
    let capabilities: Set<PassCapability>
    let missingDependencies: [String]
    let isKnown: Bool

    var activePath: URL? { filePath }
}
