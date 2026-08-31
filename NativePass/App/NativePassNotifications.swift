import Foundation

extension Notification.Name {
    static let nativePassNewEntry = Notification.Name("nativePassNewEntry")
    static let nativePassFocusSearch = Notification.Name("nativePassFocusSearch")
    static let nativePassCopyPassword = Notification.Name("nativePassCopyPassword")
    static let nativePassCopyRawEntry = Notification.Name("nativePassCopyRawEntry")
    static let nativePassPasswordCopiedInline = Notification.Name("nativePassPasswordCopiedInline")
    static let nativePassLockNow = Notification.Name("nativePassLockNow")
    static let nativePassDidLock = Notification.Name("nativePassDidLock")
    static let nativePassGitPull = Notification.Name("nativePassGitPull")
    static let nativePassGitPush = Notification.Name("nativePassGitPush")
}
