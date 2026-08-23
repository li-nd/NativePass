import SwiftUI

struct VerificationCodeDetailSection: View {
    @Environment(AppState.self) private var appState

    let entryName: String
    let hasOTPMarker: Bool
    let otpauthLine: String?
    let isEditing: Bool
    @Binding var pendingOTPURI: String

    @State private var otpInfo: OTPInfo?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showOTPInput = false

    var body: some View {
        if isEditing {
            if appState.registry.hasOTP {
                editContent
            } else if otpauthLine != nil {
                configuredReadOnlyContent
            }
        } else if hasOTPMarker {
            viewContentWithOTP
                .task(id: taskIdentity) {
                    await loadOTP()
                }
        }
    }

    private var taskIdentity: String {
        "\(entryName)|\(otpauthLine ?? "")"
    }

    @ViewBuilder
    private var viewContentWithOTP: some View {
        DetailGroupCard {
            if isLoading {
                DetailGroupRow(label: "Code", value: "…")
            } else if let errorMessage {
                DetailGroupRow(label: "Code", value: "—")
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else if let otpInfo {
                otpCodeTimeline(otpInfo)
            } else {
                DetailGroupRow(label: "Code", value: "…")
            }
        }
    }

    @ViewBuilder
    private var configuredReadOnlyContent: some View {
        DetailGroupCard {
            DetailGroupRow(label: "Code", value: String(localized: "Configured"))
            if let otpauthLine {
                Text(otpauthLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            if !appState.registry.hasOTP {
                Text("Install pass-otp to add or change verification codes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var editContent: some View {
        DetailGroupCard {
            if let otpauthLine {
                configuredReadOnlyContentInner
            } else {
                DetailGroupRow(label: "Code", value: "—")
                if showOTPInput {
                    TextField("otpauth://totp/...", text: $pendingOTPURI)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                DetailGroupDivider()
                DetailGroupActionRow(title: "Set Up Code…") {
                    showOTPInput = true
                }
            }
        }
    }

    @ViewBuilder
    private var configuredReadOnlyContentInner: some View {
        DetailGroupRow(label: "Code", value: String(localized: "Configured"))
        if let otpauthLine {
            Text(otpauthLine)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func otpCodeTimeline(_ otpInfo: OTPInfo) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let code = TOTPGenerator.generateCode(from: otpInfo, at: context.date)
            let remaining = otpRemainingSeconds(at: context.date, period: TimeInterval(otpInfo.period))
            let progress = 1 - (remaining / TimeInterval(otpInfo.period))

            VStack(spacing: 0) {
                DetailGroupRow(
                    label: "Code",
                    value: code,
                    onCopy: { appState.clipboard.copy(code) }
                )
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 12)
                Text("Refreshes in \(Int(ceil(remaining)))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private func otpRemainingSeconds(at date: Date, period: TimeInterval) -> TimeInterval {
        let epoch = date.timeIntervalSince1970
        return period - (epoch.truncatingRemainder(dividingBy: period))
    }

    private func loadOTP() async {
        guard !appState.appLock.isBlocking else { return }
        guard hasOTPMarker else { return }

        isLoading = true
        errorMessage = nil
        otpInfo = nil
        defer { isLoading = false }

        do {
            otpInfo = try await OTPInfoLoader.resolve(
                entryName: entryName,
                otpauthLine: otpauthLine,
                otpService: appState.otp
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
