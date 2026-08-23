import SwiftUI

struct FieldRow: View {
    let label: String
    let value: String
    var isSecret: Bool = false
    var isRevealed: Bool = false
    var onCopy: (() -> Void)?
    var onReveal: (() -> Void)?
    var onOpenURL: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Group {
                if isSecret && !isRevealed {
                    Text(String(repeating: "•", count: max(value.count, 8)))
                        .font(.body.monospaced())
                } else {
                    Text(value)
                        .font(isSecret ? .body.monospaced() : .body)
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                if isSecret, let onReveal {
                    Button(isRevealed ? "Hide" : "Reveal", action: onReveal)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                if let onCopy {
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy")
                }
                if let onOpenURL {
                    Button {
                        onOpenURL()
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Open")
                }
            }
        }
        .padding(.vertical, 6)
    }
}
