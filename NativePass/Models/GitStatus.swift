import Foundation

enum GitSyncBadge: Sendable {
    case upToDate
    case dirty
    case pull
    case push
    case both
}

struct GitStatus: Sendable {
    let branch: String?
    let isClean: Bool
    let changedFilesCount: Int
    let aheadCount: Int
    let behindCount: Int
    let hasUpstream: Bool
    let porcelainOutput: String

    var syncBadge: GitSyncBadge {
        if !hasUpstream {
            return isClean ? .upToDate : .dirty
        }
        if aheadCount > 0 && behindCount > 0 { return .both }
        if aheadCount > 0 { return .push }
        if behindCount > 0 { return .pull }
        return isClean ? .upToDate : .dirty
    }
}
