import AppKit
import Carbon
import SwiftUI

@Observable
final class QuickAccessController: @unchecked Sendable {
    @MainActor private var panel: NSPanel?
    @MainActor private weak var appState: AppState?
    @MainActor private weak var hostingView: NSView?
    @MainActor private var keyMonitor: Any?
    @MainActor private var focusTask: Task<Void, Never>?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private static let cardSize = NSSize(width: 420, height: 420)
    private static let cornerRadius: CGFloat = 16
    /// Space around the card so the layer shadow is not clipped by the window.
    private static let shadowMargin: CGFloat = 24

    @MainActor
    var isVisible: Bool { panel?.isVisible == true }

    @MainActor
    func configure(appState: AppState) {
        self.appState = appState
        registerHotKey()
    }

    @MainActor
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    @MainActor
    func show() {
        guard let appState else { return }

        if panel == nil {
            panel = makePanel()
        }
        guard let panel else { return }
        installContent(appState: appState, into: panel)
        positionPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if let hostingView {
            panel.makeFirstResponder(hostingView)
        }
        if !appState.appLock.isBlocking {
            scheduleSearchFieldFocus(in: panel)
        }
        installKeyMonitor()
    }

    @MainActor
    func hide() {
        focusTask?.cancel()
        focusTask = nil
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    @MainActor
    private func makePanel() -> NSPanel {
        let size = Self.windowSize
        let panel = QuickAccessPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        return panel
    }

    @MainActor
    private func installContent(appState: AppState, into panel: NSPanel) {
        let margin = Self.shadowMargin
        let card = Self.cardSize
        let rootSize = Self.windowSize

        // Root: clear, does not clip — leaves room for the shadow.
        let root = NSView(frame: NSRect(origin: .zero, size: rootSize))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        root.layer?.masksToBounds = false

        // Outer: draws the rounded shadow (masksToBounds = false).
        let outer = NSView(frame: NSRect(x: margin, y: margin, width: card.width, height: card.height))
        outer.wantsLayer = true
        outer.layer?.masksToBounds = false
        outer.layer?.backgroundColor = NSColor.clear.cgColor
        outer.layer?.shadowColor = NSColor.black.cgColor
        outer.layer?.shadowOpacity = 0.35
        outer.layer?.shadowRadius = 12
        outer.layer?.shadowOffset = .zero
        outer.layer?.shadowPath = CGPath(
            roundedRect: outer.bounds,
            cornerWidth: Self.cornerRadius,
            cornerHeight: Self.cornerRadius,
            transform: nil
        )

        // Inner: clipped rounded content.
        let hosting = NSHostingView(rootView: QuickAccessView(onClose: { [weak self] in
            Task { @MainActor in self?.hide() }
        }).environment(appState))
        hosting.frame = outer.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = Self.cornerRadius
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true

        outer.addSubview(hosting)
        root.addSubview(outer)
        panel.contentView = root
        panel.setContentSize(rootSize)
        hostingView = hosting
    }

    /// FocusState alone is unreliable in an NSPanel hosting view; drive AppKit first responder.
    @MainActor
    private func scheduleSearchFieldFocus(in panel: NSPanel) {
        focusTask?.cancel()
        focusTask = Task { @MainActor in
            for delay in [0, 30, 80, 160] as [UInt64] {
                if delay > 0 {
                    try? await Task.sleep(for: .milliseconds(delay))
                }
                guard !Task.isCancelled, self.isVisible, self.panel === panel else { return }
                if focusSearchField(in: panel) {
                    return
                }
            }
        }
    }

    @MainActor
    @discardableResult
    private func focusSearchField(in panel: NSPanel) -> Bool {
        guard let field = Self.findEditableTextField(in: panel.contentView) else {
            if let hostingView {
                return panel.makeFirstResponder(hostingView)
            }
            return false
        }
        panel.initialFirstResponder = field
        return panel.makeFirstResponder(field)
    }

    private static func findEditableTextField(in root: NSView?) -> NSView? {
        guard let root else { return nil }
        if let textField = root as? NSTextField, textField.isEditable {
            return textField
        }
        // SwiftUI may wrap the field; prefer the field editor's target when present.
        for subview in root.subviews {
            if let found = findEditableTextField(in: subview) {
                return found
            }
        }
        return nil
    }

    @MainActor
    private func positionPanel(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        var frame = panel.frame
        frame.origin = NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - frame.height / 2)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
            frame.origin.y = min(max(frame.origin.y, visible.minY + 8), visible.maxY - frame.height - 8)
        }
        panel.setFrame(frame, display: true)
    }

    @MainActor
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            precondition(Thread.isMainThread)
            return MainActor.assumeIsolated {
                self.handleKeyEvent(event)
            }
        }
    }

    @MainActor
    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    @MainActor
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isVisible, let panel, NSApp.keyWindow == panel || event.window == panel else {
            return event
        }

        if event.keyCode == 53 {
            hide()
            return nil
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            hide()
            return nil
        }

        return event
    }

    @MainActor
    private func registerHotKey() {
        guard hotKeyRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<QuickAccessController>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                controller.toggle()
            }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E_50_41_53), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private static var windowSize: NSSize {
        NSSize(
            width: cardSize.width + shadowMargin * 2,
            height: cardSize.height + shadowMargin * 2
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

private final class QuickAccessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
