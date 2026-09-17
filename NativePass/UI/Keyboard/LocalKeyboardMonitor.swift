import AppKit
import SwiftUI

/// Local key-down monitor scoped to the host view's window.
/// Return `nil` from `handler` to swallow the event.
struct LocalKeyboardMonitor: NSViewRepresentable {
    var isEnabled: Bool = true
    var handler: (NSEvent, NSWindow?) -> NSEvent?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.hostView = view
        context.coordinator.isEnabled = isEnabled
        context.coordinator.handler = handler
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isEnabled = isEnabled
        context.coordinator.handler = handler
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var hostView: NSView?
        var isEnabled = true
        var handler: ((NSEvent, NSWindow?) -> NSEvent?)?
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.isEnabled, let hostView = self.hostView, hostView.window != nil else {
                    return event
                }
                if let eventWindow = event.window, eventWindow !== hostView.window {
                    return event
                }
                // Do not use `?? event` — `nil` must swallow the event.
                guard let handler else { return event }
                return handler(event, hostView.window)
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

enum FocusAnchorID {
    static let quickAccessList = "nativepass.quickAccessList"
}

enum KeyboardKeyCode {
    static let tab: UInt16 = 48
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let one: UInt16 = 18
    static let two: UInt16 = 19
}

enum AppKitFocusHelper {
    static func focusEditableSearchField(in window: NSWindow?) {
        guard let window, let field = findEditableTextField(in: window.contentView) else { return }
        window.makeFirstResponder(field)
    }

    /// Focus a main-window column by leading table index (0 = sidebar, 1 = entry list).
    /// `.search` is handled by SwiftUI `searchFocused` in `MainView`.
    static func focusMainPane(_ pane: MainPaneFocus, in window: NSWindow?) {
        guard let window else { return }

        switch pane {
        case .sidebar:
            _ = focusLeadingTable(in: window, index: 0)
        case .list:
            _ = focusLeadingTable(in: window, index: 1)
        case .search:
            break
        }
    }

    @discardableResult
    static func focusLeadingTable(in window: NSWindow, index: Int) -> Bool {
        let tables = leadingTables(in: window)
        guard index < tables.count else { return false }
        return window.makeFirstResponder(tables[index])
    }

    /// Quick Access list focus (single table near a registered id, else first table).
    static func focusTableNearAnchor(in window: NSWindow?, anchorID: String) {
        guard let window, let content = window.contentView else { return }
        if let anchor = findView(withIdentifier: anchorID, in: content),
           let table = nearestTable(from: anchor) {
            _ = window.makeFirstResponder(table)
            return
        }
        if let table = leadingTables(in: window).first {
            _ = window.makeFirstResponder(table)
        }
    }

    static func preferredWindow(fallback: NSWindow? = nil) -> NSWindow? {
        if let fallback, fallback.isVisible { return fallback }
        if let key = NSApp.keyWindow, key.isVisible { return key }
        if let main = NSApp.mainWindow, main.isVisible { return main }
        return NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain })
    }

    static func findEditableTextField(in root: NSView?) -> NSTextField? {
        guard let root else { return nil }
        if let textField = root as? NSTextField, textField.isEditable {
            return textField
        }
        for subview in root.subviews {
            if let found = findEditableTextField(in: subview) {
                return found
            }
        }
        return nil
    }

    private static func leadingTables(in window: NSWindow) -> [NSTableView] {
        guard let content = window.contentView else { return [] }
        return allTableViews(in: content)
            .filter { table in
                let frame = table.convert(table.bounds, to: content)
                return frame.width >= 30 && frame.height >= 30
            }
            .sorted { a, b in
                a.convert(a.bounds, to: content).minX < b.convert(b.bounds, to: content).minX
            }
    }

    private static func nearestTable(from anchor: NSView) -> NSTableView? {
        var current: NSView? = anchor
        var candidate: NSTableView?
        while let view = current {
            let tables = allTableViews(in: view)
            if tables.count == 1 {
                candidate = tables[0]
            } else if tables.count > 1 {
                return candidate ?? tables[0]
            }
            current = view.superview
        }
        return candidate
    }

    private static func allTableViews(in root: NSView) -> [NSTableView] {
        var result: [NSTableView] = []
        if let table = root as? NSTableView {
            result.append(table)
        }
        for subview in root.subviews {
            result.append(contentsOf: allTableViews(in: subview))
        }
        return result
    }

    private static func findView(withIdentifier id: String, in root: NSView?) -> NSView? {
        guard let root else { return nil }
        if root.identifier?.rawValue == id { return root }
        for subview in root.subviews {
            if let found = findView(withIdentifier: id, in: subview) {
                return found
            }
        }
        return nil
    }
}

enum ListSelectionMovement {
    static func move<T: Equatable>(selection: inout T?, in items: [T], delta: Int) {
        guard !items.isEmpty else { return }
        if let current = selection, let index = items.firstIndex(of: current) {
            let next = min(max(index + delta, 0), items.count - 1)
            selection = items[next]
        } else {
            selection = delta >= 0 ? items.first : items.last
        }
    }
}
