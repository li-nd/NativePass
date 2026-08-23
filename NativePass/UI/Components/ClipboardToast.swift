import SwiftUI

struct ClipboardToast: View {
    let message: String
    let onDismiss: () -> Void

    private var isCopyConfirmation: Bool {
        message.hasPrefix("Copied")
    }

    var body: some View {
        Group {
            if isCopyConfirmation {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .symbolRenderingMode(.hierarchical)
                    Text(message)
                        .font(.caption)
                }
            } else {
                Text(message)
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onTapGesture(perform: onDismiss)
    }
}

extension View {
    func clipboardToast(message: String?, onDismiss: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom) {
            if let message {
                ClipboardToast(message: message, onDismiss: onDismiss)
                    .padding(.bottom, 8)
            }
        }
    }
}
