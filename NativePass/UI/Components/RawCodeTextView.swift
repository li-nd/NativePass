import AppKit
import SwiftUI

/// Monospaced `NSTextView` with a layout-synced line-number gutter.
struct RawCodeTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var onEditingChanged: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.usesFindBar = true
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        applyChrome(to: textView, editable: isEditable)
        textView.string = text

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.rulersVisible = true
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = ruler

        context.coordinator.textView = textView
        context.coordinator.rulerView = ruler

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        applyChrome(to: textView, editable: isEditable)

        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }

        context.coordinator.parent = self
        context.coordinator.rulerView?.invalidateLineNumbers()
    }

    private func applyChrome(to textView: NSTextView, editable: Bool) {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.font = font
        textView.isEditable = editable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
        textView.textContainer?.lineFragmentPadding = 8
        textView.textContainerInset = NSSize(width: 4, height: 8)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RawCodeTextView
        weak var textView: NSTextView?
        weak var rulerView: LineNumberRulerView?

        init(_ parent: RawCodeTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            rulerView?.invalidateLineNumbers()
            parent.onEditingChanged?()
        }
    }
}

// MARK: - Line numbers

final class LineNumberRulerView: NSRulerView {
    private weak var observedTextView: NSTextView?

    private var lineNumberFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    }

    init(textView: NSTextView) {
        self.observedTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
        needsDisplay = true

        textView.postsFrameChangedNotifications = true
        textView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func invalidateLineNumbers() {
        let digits = max(lineCountDigits(), 2)
        let thickness = CGFloat(digits) * 9 + 18
        if abs(ruleThickness - thickness) > 0.5 {
            ruleThickness = thickness
        }
        needsDisplay = true
    }

    @objc private func refresh() {
        invalidateLineNumbers()
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.quaternaryLabelColor.withAlphaComponent(0.12).setFill()
        bounds.fill()

        guard
            let textView = clientView as? NSTextView ?? observedTextView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return }

        let relativePoint = self.convert(NSPoint.zero, from: textView)
        let visibleRect = textView.visibleRect
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        var lineNumber = startingLineNumber(
            forGlyphIndex: glyphRange.location,
            layoutManager: layoutManager,
            string: textView.string as NSString
        )

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { fragmentRect, _, _, fragmentGlyphRange, _ in
            let characterRange = layoutManager.characterRange(
                forGlyphRange: fragmentGlyphRange,
                actualGlyphRange: nil
            )
            let isHardLineStart: Bool
            if characterRange.location == 0 {
                isHardLineStart = true
            } else {
                let previous = (textView.string as NSString).character(at: characterRange.location - 1)
                isHardLineStart = previous == 10 || previous == 13
            }

            if isHardLineStart {
                let label = "\(lineNumber)" as NSString
                let size = label.size(withAttributes: textAttributes)
                let x = self.ruleThickness - size.width - 8
                let y = relativePoint.y
                    + fragmentRect.minY
                    + textView.textContainerInset.height
                    + (fragmentRect.height - size.height) / 2
                label.draw(at: NSPoint(x: x, y: y), withAttributes: textAttributes)
                lineNumber += 1
            }
        }

        NSColor.separatorColor.withAlphaComponent(0.6).setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        path.lineWidth = 1
        path.stroke()
    }

    private func lineCountDigits() -> Int {
        guard let textView = observedTextView else { return 2 }
        let count = max(textView.string.components(separatedBy: "\n").count, 1)
        return String(count).count
    }

    private func startingLineNumber(
        forGlyphIndex glyphIndex: Int,
        layoutManager: NSLayoutManager,
        string: NSString
    ) -> Int {
        guard layoutManager.numberOfGlyphs > 0 else { return 1 }
        let safeGlyph = min(max(glyphIndex, 0), layoutManager.numberOfGlyphs - 1)
        let characterIndex = layoutManager.characterIndexForGlyph(at: safeGlyph)
        guard characterIndex > 0 else { return 1 }

        var line = 1
        string.enumerateSubstrings(
            in: NSRange(location: 0, length: characterIndex),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            line += 1
        }
        return line
    }
}
