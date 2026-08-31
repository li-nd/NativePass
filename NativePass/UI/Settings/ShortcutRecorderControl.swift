import AppKit
import Carbon
import SwiftUI

/// Compact control that records a shortcut from the next key press.
struct ShortcutRecorderControl: View {
    @Binding var binding: ShortcutBinding
    var onReset: (() -> Void)?

    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording.toggle()
            } label: {
                Text(isRecording ? String(localized: "Type shortcut…") : binding.displayString)
                    .font(.body.monospaced())
                    .frame(minWidth: 88, alignment: .center)
            }
            .buttonStyle(.bordered)
            .help(isRecording ? "Press the new shortcut, or Esc to cancel" : "Click to record a new shortcut")

            if let onReset, binding != .quickAccessDefault {
                Button("Reset") { onReset() }
                    .buttonStyle(.borderless)
            }
        }
        .background {
            ShortcutCaptureMonitor(isActive: $isRecording) { event in
                if event.keyCode == UInt16(kVK_Escape) {
                    isRecording = false
                    return
                }
                guard let recorded = ShortcutBinding(event: event) else { return }
                binding = recorded
                isRecording = false
            }
        }
    }
}

/// Local key monitor used only while recording.
private struct ShortcutCaptureMonitor: NSViewRepresentable {
    @Binding var isActive: Bool
    var onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKeyDown = onKeyDown
        context.coordinator.setActive(isActive)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var onKeyDown: ((NSEvent) -> Void)?
        private var monitor: Any?

        func setActive(_ active: Bool) {
            if active {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    self?.onKeyDown?(event)
                    return nil
                }
            } else if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
