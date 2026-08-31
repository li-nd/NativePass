import SwiftUI
import AppKit

struct DetailGroupCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.45))
        }
    }
}

struct DetailGroupDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 12)
    }
}

struct DetailGroupActionRow: View {
    let title: LocalizedStringKey
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct DetailGroupDestructiveRow: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer(minLength: 0)
                Text(title)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DetailGroupRow: View {
    let label: String
    var isEditing: Bool = false
    var isSecret: Bool = false
    var isRevealed: Bool = false
    var displayValue: String = ""
    @Binding var editValue: String
    var url: URL?
    var onCopy: (() -> Void)?
    var copyFeedbackScope: String?
    var onRevealToggle: (() -> Void)?

    @State private var isHovering = false

    init(
        label: String,
        value: String,
        isSecret: Bool = false,
        isRevealed: Bool = false,
        url: URL? = nil,
        onCopy: (() -> Void)? = nil,
        copyFeedbackScope: String? = nil,
        onRevealToggle: (() -> Void)? = nil
    ) {
        self.label = label
        self.isEditing = false
        self.isSecret = isSecret
        self.isRevealed = isRevealed
        self.displayValue = value
        self._editValue = .constant(value)
        self.url = url
        self.onCopy = onCopy
        self.copyFeedbackScope = copyFeedbackScope
        self.onRevealToggle = onRevealToggle
    }

    init(
        label: String,
        value: Binding<String>,
        isEditing: Bool,
        isSecret: Bool = false,
        isRevealed: Bool = false,
        onRevealToggle: (() -> Void)? = nil
    ) {
        self.label = label
        self.isEditing = isEditing
        self.isSecret = isSecret
        self.isRevealed = isRevealed
        self.displayValue = value.wrappedValue
        self._editValue = value
        self.url = nil
        self.onCopy = nil
        self.onRevealToggle = onRevealToggle
    }

    private var localizedLabel: String {
        String(localized: String.LocalizationValue(label))
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(localizedLabel)
                .foregroundStyle(.secondary)
                .frame(minWidth: 100, alignment: .leading)

            Spacer(minLength: 8)

            valueContent

            if isSecret, let onRevealToggle {
                Button(action: onRevealToggle) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .opacity(isHovering ? 1 : 0.55)
                .help(isRevealed ? "Hide Password" : "Reveal Password")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var valueContent: some View {
        Group {
            if isEditing {
                if isSecret && !isRevealed {
                    SecureField(localizedLabel, text: $editValue)
                } else {
                    TextField(localizedLabel, text: $editValue)
                        .font(isSecret ? .body.monospaced() : .body)
                }
            } else if let url {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text(displayValue)
                        .foregroundStyle(.link)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                }
                .buttonStyle(.plain)
                .help("Open in Browser")
            } else if let onCopy {
                CopyableValueText(
                    value: visibleText,
                    isMonospaced: isSecret,
                    lineLimit: isSecret ? 1 : 3,
                    feedbackScope: copyFeedbackScope,
                    onCopy: onCopy
                )
            } else if isSecret && !isRevealed {
                Text(String(repeating: "•", count: max(displayValue.count, 8)))
                    .font(.body.monospaced())
            } else {
                Text(displayValue)
                    .font(isSecret ? .body.monospaced() : .body)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(isSecret ? 1 : 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .multilineTextAlignment(.trailing)
    }

    private var visibleText: String {
        if isSecret && !isRevealed {
            return String(repeating: "•", count: max(displayValue.count, 8))
        }
        return displayValue
    }
}
