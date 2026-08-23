import Foundation

enum SidebarSelection: Hashable, Sendable {
    case all
    case folder(String)
    case verificationCodes

    var folderPath: String? {
        if case .folder(let path) = self { return path }
        return nil
    }

    var listTitle: String {
        switch self {
        case .all:
            return String(localized: "All")
        case .folder(let path):
            return path.split(separator: "/").last.map(String.init) ?? path
        case .verificationCodes:
            return String(localized: "Verification Codes")
        }
    }
}
