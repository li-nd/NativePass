import AppKit
import SwiftUI

/// View / edit the decrypted pass file as plain text, with a code-style line gutter.
/// View mode sizes to content (scrolls inside only when taller than `maxBodyHeight`).
/// Edit mode fills the remaining detail height.
struct EntryRawSection: View {
    let entryName: String
    let rawContent: String
    var isEditing: Bool = false
    /// Cap for view-mode body height; `nil` means unbounded (parent ScrollView handles overflow).
    var maxBodyHeight: CGFloat? = nil
    @Binding var editText: String
    var onCopyAll: () -> Void

    @State private var showCopied = false
    @State private var copiedFeedbackTask: Task<Void, Never>?

    private var displayedText: String {
        isEditing ? editText : rawContent
    }

    private var lines: [String] {
        let parts = displayedText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return parts.isEmpty ? [""] : parts
    }

    private var lineCount: Int { lines.count }

    private var monoFont: Font { .system(.body, design: .monospaced) }

    private var lineHeight: CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return ceil(font.ascender - font.descender + font.leading)
    }

    private var idealBodyHeight: CGFloat {
        CGFloat(lineCount) * lineHeight + 20
    }

    private var gutterWidth: CGFloat {
        let digits = max(String(lineCount).count, 2)
        return CGFloat(digits) * 9 + 16
    }

    private var gutterColumnWidth: CGFloat { gutterWidth + 8 }

    private let textLeadingPadding: CGFloat = 10
    private let textTrailingPadding: CGFloat = 14

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            Group {
                if isEditing {
                    editorBody
                } else {
                    viewerBody
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: isEditing ? .infinity : nil,
                alignment: .topLeading
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: isEditing ? .infinity : nil,
            alignment: .topLeading
        )
        .background {
            cardShape.fill(.quaternary.opacity(0.45))
        }
        .clipShape(cardShape)
        .onDisappear { copiedFeedbackTask?.cancel() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.plaintext")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(isEditing ? "Edit Raw" : "Raw")
                    .font(.subheadline.weight(.semibold))
                Text(lineCountLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            if !isEditing {
                Button(action: copyAll) {
                    Group {
                        if showCopied {
                            Label("Copied", systemImage: "checkmark")
                                .foregroundStyle(.secondary)
                        } else {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .help("Copy entire entry (⌘⇧C)")
                .disabled(rawContent.isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var lineCountLabel: String {
        lineCount == 1
            ? String(localized: "1 line")
            : String(localized: "\(lineCount) lines")
    }

    private var viewerBody: some View {
        let bodyHeight: CGFloat = {
            if let maxBodyHeight {
                return min(idealBodyHeight, maxBodyHeight)
            }
            return idealBodyHeight
        }()
        let needsVerticalScroll = maxBodyHeight.map { idealBodyHeight > $0 } ?? false

        return GeometryReader { geo in
            let textColumnWidth = max(geo.size.width - gutterColumnWidth, 0)
            ScrollView(needsVerticalScroll ? [.vertical, .horizontal] : [.horizontal], showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    lineGutter(minHeight: idealBodyHeight)
                    Text(rawContent.isEmpty ? String(localized: "(empty)") : rawContent)
                        .font(monoFont)
                        .foregroundStyle(rawContent.isEmpty ? .tertiary : .primary)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(.vertical, 10)
                        .padding(.leading, textLeadingPadding)
                        .padding(.trailing, textTrailingPadding)
                        .frame(minWidth: textColumnWidth, alignment: .topLeading)
                }
                .frame(minWidth: geo.size.width, alignment: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: bodyHeight)
    }

    private var editorBody: some View {
        RawCodeTextView(text: $editText, isEditable: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func lineGutter(minHeight: CGFloat?) -> some View {
        let numbers = Array(1...lineCount)
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(numbers, id: \.self) { number in
                Text("\(number)")
                    .font(monoFont)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(height: lineHeight, alignment: .center)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 8)
        .frame(width: gutterColumnWidth, alignment: .topTrailing)
        .frame(minHeight: minHeight, maxHeight: .infinity, alignment: .top)
        .background {
            Rectangle()
                .fill(.quaternary.opacity(0.35))
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.separator.opacity(0.6))
                .frame(width: 1)
        }
        .accessibilityHidden(true)
    }

    private func copyAll() {
        onCopyAll()
        copiedFeedbackTask?.cancel()
        showCopied = true
        copiedFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run { showCopied = false }
        }
    }
}
