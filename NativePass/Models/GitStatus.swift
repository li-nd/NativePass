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
    /// Tracking ref such as `origin/main`, when configured.
    let upstream: String?
    let isClean: Bool
    let changedFiles: [GitChangedFile]
    let aheadCount: Int
    let behindCount: Int
    let porcelainOutput: String

    var hasUpstream: Bool { upstream != nil }

    var changedFilesCount: Int { changedFiles.count }

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
