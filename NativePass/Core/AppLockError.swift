import Foundation

enum AppLockError: Error, LocalizedError {
    case locked

    var errorDescription: String? {
        switch self {
        case .locked:
            return String(localized: "NativePass is locked.")
        }
    }
}
