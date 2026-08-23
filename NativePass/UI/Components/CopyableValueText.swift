import SwiftUI

struct CopyableValueText: View {
    let value: String
    var isMonospaced: Bool = false
    var lineLimit: Int = 3
    var feedbackScope: String?
    let onCopy: () -> Void

    @State private var showCopied = false
    @State private var isHovering = false
    @State private var copiedFeedbackTask: Task<Void, Never>?

    var body: some View {
        Button(action: copy) {
            ZStack(alignment: .trailing) {
                Text(value)
                    .font(isMonospaced ? .body.monospaced() : .body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(lineLimit)
                    .opacity(showCopied ? 0 : 1)

                if showCopied {
                    CopiedFeedbackBadge(font: .caption)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                if isHovering || showCopied {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary.opacity(showCopied ? 1 : 0.85))
                }
            }
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: showCopied)
        }
        .buttonStyle(.plain)
        .help(showCopied ? "Copied" : "Copy")
        .onHover { isHovering = $0 }
        .accessibilityLabel(showCopied ? "Copied" : value)
        .accessibilityHint("Copies to clipboard")
        .onReceive(NotificationCenter.default.publisher(for: .nativePassPasswordCopiedInline)) { notification in
            guard let scope = notification.userInfo?["scope"] as? String,
                  scope == feedbackScope else { return }
            showCopiedFeedback()
        }
        .onDisappear {
            copiedFeedbackTask?.cancel()
        }
    }

    private func copy() {
        onCopy()
        showCopiedFeedback()
    }

    private func showCopiedFeedback() {
        copiedFeedbackTask?.cancel()
        showCopied = true
        copiedFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showCopied = false
            }
        }
    }
}
