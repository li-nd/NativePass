import AppKit
import Carbon
import SwiftUI

@Observable
final class QuickAccessController: @unchecked Sendable {
    @MainActor private var panel: NSPanel?
    @MainActor private weak var appState: AppState?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @MainActor
    var isVisible: Bool { panel?.isVisible == true }

    @MainActor
    func configure(appState: AppState) {
        self.appState = appState
        registerHotKey()
    }

    @MainActor
    func toggle() {
        guard let appState else { return }
        if appState.appLock.isBlocking {
            return
        }
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    @MainActor
    func show() {
        guard let appState else { return }
        if appState.appLock.isBlocking { return }

        if panel == nil {
            panel = makePanel(appState: appState)
        }
        guard let panel else { return }
        positionPanel(panel)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func hide() {
        panel?.orderOut(nil)
    }

    @MainActor
    private func makePanel(appState: AppState) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .windowBackgroundColor

        let hosting = NSHostingView(rootView: QuickAccessView(onClose: { [weak self] in
            Task { @MainActor in self?.hide() }
        }).environment(appState))
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }

    @MainActor
    private func positionPanel(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        var frame = panel.frame
        frame.origin = NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - frame.height / 2)
        panel.setFrame(frame, display: true)
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

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
