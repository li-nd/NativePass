import AppKit
import SwiftUI

struct PasswordGeneratorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var onUse: (String) -> Void
    /// When false, content is shown inside an existing `NavigationStack` (e.g. pushed from New Entry).
    var embedsNavigationStack: Bool = true

    @State private var options = AppPreferences.passwordGeneratorOptions
    @State private var preview = ""
    @State private var errorMessage: String?
    @State private var regenerateSymbolRotation = 0.0
    @State private var showCopiedFeedback = false

    private static let previewFontSize: CGFloat = 22
    private static let previewLineHeight: CGFloat = 28
    private static let sheetWidth: CGFloat = 460

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack {
                    generatorContent
                }
                .frame(width: Self.sheetWidth, height: sheetHeight)
            } else {
                generatorContent
            }
        }
        .onAppear {
            options = AppPreferences.passwordGeneratorOptions
            regenerate(animated: false)
        }
        .onDisappear {
            AppPreferences.passwordGeneratorOptions = options
        }
    }

    private var generatorContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                previewRow

                Divider()
                    .padding(.vertical, 2)

                lengthRow
                characterSetsRow
                ambiguousRow

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)

            Spacer(minLength: 0)

            Divider()

            HStack {
                Spacer(minLength: 0)
                Button("Cancel") { dismissGenerator() }
                    .keyboardShortcut(.cancelAction)
                Button("Use Password") {
                    usePassword()
                }
                .buttonStyle(.borderedProminent)
                .disabled(preview.isEmpty || !options.hasAnyCharset)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .navigationTitle(String(localized: "Generate Password"))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .automatic)
    }

    /// Grows with length so long passwords fit; stays stable while regenerating the same length.
    private var sheetHeight: CGFloat {
        let previewWidth = Self.sheetWidth - 40 - 28
        let textHeight = previewTextHeight(forLength: options.clampedLength, width: previewWidth)
        return min(520, max(340, textHeight + 260))
    }

    // MARK: - Rows

    private var previewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                let width = geo.size.width
                let length = max(preview.count, options.clampedLength, 1)
                let textHeight = previewTextHeight(forLength: length, width: width)
                coloredPreview(width: width)
                    .frame(maxWidth: .infinity, minHeight: textHeight, maxHeight: textHeight, alignment: .topLeading)
            }
            .frame(height: previewTextHeight(
                forLength: max(preview.count, options.clampedLength, 1),
                width: Self.sheetWidth - 40 - 28
            ))

            HStack(spacing: 8) {
                if showCopiedFeedback {
                    Text(String(localized: "Copied"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                Spacer(minLength: 0)
                Button {
                    regenerate(animated: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .rotationEffect(.degrees(regenerateSymbolRotation))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!options.hasAnyCharset)
                .help(String(localized: "Regenerate"))

                Button {
                    copyPreview()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(preview.isEmpty)
                .help(String(localized: "Copy"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.45))
        }
    }

    private func coloredPreview(width: CGFloat) -> some View {
        let lines = displayedPreviewLines(width: width)
        return VStack(alignment: .leading, spacing: 0) {
            if lines.isEmpty {
                Text("—")
                    .font(.system(size: Self.previewFontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(attributedLine(line))
                        .font(.system(size: Self.previewFontSize, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy(duration: 0.2), value: preview)
    }

    private func attributedLine(_ line: String) -> AttributedString {
        var result = AttributedString()
        for character in line {
            var piece = AttributedString(String(character))
            piece.foregroundColor = color(for: character)
            result.append(piece)
        }
        return result
    }

    private func color(for character: Character) -> Color {
        if character.isNumber {
            return Color(red: 0.35, green: 0.62, blue: 1.0)
        }
        if character.isLetter {
            return .primary
        }
        return Color(red: 1.0, green: 0.45, blue: 0.55)
    }

    /// Hard-wraps by character count so layout never depends on glyph widths.
    private func displayedPreviewLines(width: CGFloat) -> [String] {
        guard !preview.isEmpty else { return [] }
        let perLine = charactersPerLine(forWidth: width)
        var lines: [String] = []
        var start = preview.startIndex
        while start < preview.endIndex {
            let end = preview.index(start, offsetBy: perLine, limitedBy: preview.endIndex) ?? preview.endIndex
            lines.append(String(preview[start..<end]))
            start = end
        }
        return lines
    }

    private func previewTextHeight(forLength length: Int, width: CGFloat) -> CGFloat {
        let lines = lineCount(forLength: length, width: width)
        return CGFloat(lines) * Self.previewLineHeight
    }

    private func lineCount(forLength length: Int, width: CGFloat) -> Int {
        let perLine = charactersPerLine(forWidth: width)
        return max(1, (max(length, 1) + perLine - 1) / perLine)
    }

    private func charactersPerLine(forWidth width: CGFloat) -> Int {
        let font = NSFont.monospacedSystemFont(ofSize: Self.previewFontSize, weight: .medium)
        let charWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
        return max(Int(floor(max(width, 1) / max(charWidth, 1))), 1)
    }

    private var lengthRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "Length"))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Slider(
                value: Binding(
                    get: { Double(options.clampedLength) },
                    set: { newValue in
                        let length = Int(newValue.rounded())
                        guard length != options.length else { return }
                        options.length = length
                        regenerate(animated: false)
                    }
                ),
                in: Double(PasswordGeneratorOptions.minimumLength)...Double(PasswordGeneratorOptions.maximumLength),
                step: 1
            )

            Text("\(options.clampedLength)")
                .font(.callout.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                }
                .frame(minWidth: 44, alignment: .center)
                .contentTransition(.numericText())
        }
    }

    private var characterSetsRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "Include"))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            HStack(spacing: 8) {
                charsetChip("A–Z", isOn: uppercaseBinding)
                charsetChip("a–z", isOn: lowercaseBinding)
                charsetChip("0–9", isOn: digitsBinding)
                charsetChip("!@#", isOn: symbolsBinding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ambiguousRow: some View {
        Toggle(isOn: ambiguousBinding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Avoid Ambiguous Characters"))
                Text(String(localized: "0, O, l, I, 1, |"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }

    private func charsetChip(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.callout.weight(.medium).monospaced())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isOn.wrappedValue ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.12),
                            lineWidth: 1
                        )
                }
                .foregroundStyle(isOn.wrappedValue ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    // MARK: - Bindings

    private var uppercaseBinding: Binding<Bool> {
        optionToggleBinding(\.includeUppercase)
    }

    private var lowercaseBinding: Binding<Bool> {
        optionToggleBinding(\.includeLowercase)
    }

    private var digitsBinding: Binding<Bool> {
        optionToggleBinding(\.includeDigits)
    }

    private var symbolsBinding: Binding<Bool> {
        optionToggleBinding(\.includeSymbols)
    }

    private var ambiguousBinding: Binding<Bool> {
        optionToggleBinding(\.avoidAmbiguous)
    }

    private func optionToggleBinding(_ keyPath: WritableKeyPath<PasswordGeneratorOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { options[keyPath: keyPath] },
            set: { newValue in
                guard options[keyPath: keyPath] != newValue else { return }
                options[keyPath: keyPath] = newValue
                regenerate(animated: false)
            }
        )
    }

    // MARK: - Actions

    private func regenerate(animated: Bool) {
        errorMessage = nil
        guard options.hasAnyCharset else {
            preview = ""
            errorMessage = String(localized: "Select at least one character set.")
            return
        }
        do {
            let next = try PasswordGenerator.generate(options: options)
            if animated {
                withAnimation(.snappy(duration: 0.35)) {
                    regenerateSymbolRotation += 360
                    preview = next
                }
            } else {
                preview = next
            }
        } catch {
            preview = ""
            errorMessage = error.localizedDescription
        }
    }

    private func copyPreview() {
        guard !preview.isEmpty else { return }
        appState.clipboard.copy(preview, showToast: false)
        withAnimation(.snappy(duration: 0.2)) {
            showCopiedFeedback = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCopiedFeedback = false
                }
            }
        }
    }

    private func usePassword() {
        guard !preview.isEmpty else { return }
        AppPreferences.passwordGeneratorOptions = options
        onUse(preview)
        dismissGenerator()
    }

    private func dismissGenerator() {
        dismiss()
    }
}
