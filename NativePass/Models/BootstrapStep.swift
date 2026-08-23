import Foundation

enum BootstrapStep: Int, CaseIterable, Sendable {
    case starting
    case checkingPlugins
    case scanningStore
    case preparingWorkspace
    case ready

    var label: String {
        switch self {
        case .starting:
            return String(localized: "Starting NativePass…")
        case .checkingPlugins:
            return String(localized: "Checking plugins…")
        case .scanningStore:
            return String(localized: "Scanning password store…")
        case .preparingWorkspace:
            return String(localized: "Preparing workspace…")
        case .ready:
            return String(localized: "Ready")
        }
    }

    var progress: Double {
        let last = Double(Self.allCases.count - 1)
        guard last > 0 else { return 1 }
        return Double(rawValue) / last
    }
}
