import AppKit
import SwiftUI

/// View / edit the decrypted pass file as plain text, with a code-style line gutter.
/// View mode sizes to content (scrolls inside only when taller than `maxBodyHeight`).
/// Edit mode fills the remaining detail height.
/// In view mode, Copy copies the highlighted range when present (same as multiline Form fields).
struct EntryRawSection: View {
    let entryName: String
    let rawContent: String
    var isEditing: Bool = false
    /// Cap for view-mode body height; `nil` means unbounded (parent ScrollView handles overflow).
    var maxBodyHeight: CGFloat? = nil
    @Binding var editText: String
    var onCopy: (String) -> Void

    @State private var selectedText = ""
    @State private var showCopied = false
    @State private var copiedFeedbackTask: Task<Void, Never>?

    private var displayedText: String {
        isEditing ? editText : rawContent
    }

    private var lineCount: Int {
        let parts = displayedText.split(separator: "\n", omittingEmptySubsequences: false)
        return max(parts.count, 1)
    }

    private var lineHeight: CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return ceil(font.ascender - font.descender + font.leading)
    }

    private var idealBodyHeight: CGFloat {
        CGFloat(lineCount) * lineHeight + 20
    }

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
        .onDisappear {
            copiedFeedbackTask?.cancel()
            selectedText = ""
        }
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
                Button {
                    copy(selectedText.isEmpty ? rawContent : selectedText)
                } label: {
                    Group {
                        if showCopied {
                            Label("Copied", systemImage: "checkmark")
                                .foregroundStyle(.secondary)
                        } else {
                            Label(copyButtonTitle, systemImage: "doc.on.doc")
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .help(selectedText.isEmpty ? "Copy entire entry (⌘⇧C)" : "Copy highlighted text")
                .disabled(rawContent.isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var copyButtonTitle: LocalizedStringKey {
        selectedText.isEmpty ? "Copy All" : "Copy Selection"
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

        return RawCodeTextView(
            text: .constant(rawContent),
            isEditable: false,
            selectedText: $selectedText,
            onCopy: copy
        )
        .frame(maxWidth: .infinity)
        .frame(height: bodyHeight)
    }

    private var editorBody: some View {
        RawCodeTextView(text: $editText, isEditable: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        onCopy(text)
        copiedFeedbackTask?.cancel()
        showCopied = true
        copiedFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run { showCopied = false }
        }
    }
}
