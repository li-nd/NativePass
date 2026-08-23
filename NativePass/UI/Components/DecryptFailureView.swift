import SwiftUI

struct DecryptFailureView: View {
    @Environment(AppState.self) private var appState

    let guide: DecryptRecoveryGuide
    var onRetry: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ContentUnavailableView {
                    Label(guide.title, systemImage: systemImage)
                } description: {
                    Text(guide.explanation)
                        .multilineTextAlignment(.center)
                }

                if let onRetry {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Steps")
                        .font(.headline)

                    ForEach(Array(guide.steps.enumerated()), id: \.element.id) { index, step in
                        recoveryStepRow(number: index + 1, step: step)
                    }
                }
                .frame(maxWidth: 420, alignment: .leading)
                .padding(.horizontal, 4)

                if !guide.gpgRecipientIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Store recipient IDs")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(guide.gpgRecipientIDs.joined(separator: ", "))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                }

                Text("Details: \(guide.rawError)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
    }

    private var systemImage: String {
        switch guide.kind {
        case .pinentryNotConfigured, .keyLocked:
            "lock.fill"
        case .keyMissing:
            "key.slash"
        case .userCancelled:
            "hand.raised"
        case .agentUnavailable:
            "exclamationmark.triangle"
        case .unknown:
            "exclamationmark.triangle"
        }
    }

    @ViewBuilder
    private func recoveryStepRow(number: Int, step: RecoveryStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(number). \(step.title)")
                .font(.subheadline.weight(.medium))

            if let detail = step.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let command = step.command {
                HStack(alignment: .top, spacing: 8) {
                    Text(command)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

                    Button("Copy") {
                        appState.clipboard.copy(command, clearAfter: 0)
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}
