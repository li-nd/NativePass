import Foundation

/// Keyboard focus targets for the main window.
enum MainPaneFocus: String, Hashable {
    case sidebar
    case list
    case search
}

enum MainPaneFocusNotification {
    static let paneKey = "pane"
    static let backwardKey = "backward"

    static func post(_ pane: MainPaneFocus) {
        NotificationCenter.default.post(
            name: .nativePassFocusPane,
            object: nil,
            userInfo: [paneKey: pane.rawValue]
        )
    }

    static func postCycle(backward: Bool) {
        NotificationCenter.default.post(
            name: .nativePassCyclePane,
            object: nil,
            userInfo: [backwardKey: backward]
        )
    }

    static func pane(from notification: Notification) -> MainPaneFocus? {
        guard let raw = notification.userInfo?[paneKey] as? String else { return nil }
        return MainPaneFocus(rawValue: raw)
    }

    static func isBackward(from notification: Notification) -> Bool {
        (notification.userInfo?[backwardKey] as? Bool) ?? false
    }
}
