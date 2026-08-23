import SwiftUI

struct PasswordDetailSection: View {
    @Binding var password: String
    let isEditing: Bool
    @Binding var isRevealed: Bool
    var copyFeedbackScope: String?
    var isGenerating: Bool = false
    var onCopy: () -> Void
    var onRevealToggle: () -> Void
    var onGenerate: (() -> Void)?

    var body: some View {
        if isEditing {
            DetailGroupRow(
                label: "Password",
                value: $password,
                isEditing: true,
                isSecret: true,
                isRevealed: isRevealed,
                onRevealToggle: onRevealToggle
            )
            DetailGroupDivider()
            DetailGroupActionRow(
                title: "Generate Password…",
                isDisabled: isGenerating,
                action: { onGenerate?() }
            )
        } else {
            DetailGroupRow(
                label: "Password",
                value: password,
                isSecret: true,
                isRevealed: isRevealed,
                onCopy: onCopy,
                copyFeedbackScope: copyFeedbackScope,
                onRevealToggle: onRevealToggle
            )
        }
    }
}
