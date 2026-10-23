import AppKit
import SwiftUI

/// Read-only, selectable monospaced text. Every way of copying out of it (⌘C, Edit ▸ Copy,
/// the context menu) goes through `onCopy` — the app's sensitive clipboard — instead of
/// the system pasteboard. Dragging, Services and Writing Tools are disabled.
struct SafeSelectableTextView: NSViewRepresentable {
    let text: String
    var maxHeight: CGFloat = 320
    @Binding var selectedText: String
    let onCopy: (String) -> Void

    private static let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    private static let textInset = NSSize(width: 4, height: 8)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SafeCopyTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.font = Self.font
        textView.textContainerInset = Self.textInset
        textView.writingToolsBehavior = .none
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text
        textView.delegate = context.coordinator
        textView.onCopy = { [weak coordinator = context.coordinator] selection in
            coordinator?.parent.onCopy(selection)
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? SafeCopyTextView,
              textView.string != text else { return }
        context.coordinator.isUpdatingText = true
        textView.string = text
        context.coordinator.isUpdatingText = false
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let lineFragmentPadding = (nsView.documentView as? NSTextView)?.textContainer?.lineFragmentPadding ?? 5
        let textWidth = max(width - 2 * Self.textInset.width - 2 * lineFragmentPadding, 1)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Self.font]
        )
        let height = ceil(bounds.height) + 2 * Self.textInset.height
        return CGSize(width: width, height: min(height, maxHeight))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SafeSelectableTextView
        var isUpdatingText = false

        init(_ parent: SafeSelectableTextView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdatingText, let textView = notification.object as? SafeCopyTextView else { return }
            let selection = textView.selectedSubstring
            if parent.selectedText != selection {
                parent.selectedText = selection
            }
        }
    }
}

final class SafeCopyTextView: NSTextView {
    var onCopy: ((String) -> Void)?

    /// Highlighted text; multiple (⌥-drag) selections are joined by newlines.
    var selectedSubstring: String {
        let content = string as NSString
        return selectedRanges
            .map { content.substring(with: $0.rangeValue) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    override func copy(_ sender: Any?) {
        let selection = selectedSubstring
        guard !selection.isEmpty else { return }
        onCopy?(selection)
    }

    /// ⌘C is the app-wide "Copy Password" shortcut; claim it only while text here is highlighted.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "c",
           window?.firstResponder === self,
           !selectedSubstring.isEmpty {
            copy(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Only Copy and Select All — no Services, Share, Look Up or Writing Tools.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: String(localized: "Copy"), action: #selector(copy(_:)), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)
        let selectAllItem = NSMenuItem(title: String(localized: "Select All"), action: #selector(selectAll(_:)), keyEquivalent: "")
        selectAllItem.target = self
        menu.addItem(selectAllItem)
        return menu
    }

    // Dragging or Services would put the selection on a pasteboard without protection.
    override func dragSelection(with event: NSEvent, offset mouseOffset: NSSize, slideBack: Bool) -> Bool {
        false
    }

    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        false
    }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        false
    }

    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any? {
        nil
    }
}
