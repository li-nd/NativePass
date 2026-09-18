import SwiftUI

struct VerificationCodeDetailSection: View {
    @Environment(AppState.self) private var appState

    let entryName: String
    let hasOTPMarker: Bool
    let isEditing: Bool
    @Binding var otpauthLine: String?
    @Binding var pendingOTPInput: String

    @State private var otpInfo: OTPInfo?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showOTPInput = false
    @State private var setupError: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        if isEditing {
            editContent
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

    private var effectiveOTPAuthLine: String? {
        if let otpauthLine, !otpauthLine.isEmpty { return otpauthLine }
        return nil
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
                configuredCodeCard(otpInfo: otpInfo, setupURL: effectiveOTPAuthLine)
            } else {
                DetailGroupRow(label: "Code", value: "…")
            }
        }
    }

    @ViewBuilder
    private var editContent: some View {
        DetailGroupCard {
            if let line = effectiveOTPAuthLine {
                configuredEditContent(setupURL: line)
            } else {
                unconfiguredEditContent
            }
        }
        .confirmationDialog(
            "Delete verification code?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Code", role: .destructive) {
                otpauthLine = nil
                pendingOTPInput = ""
                showOTPInput = false
                setupError = nil
                otpInfo = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The OTP secret will be removed from this entry.")
        }
    }

    @ViewBuilder
    private var unconfiguredEditContent: some View {
        DetailGroupRow(label: "Code", value: String(localized: "None"))

        if showOTPInput {
            TextField(
                "",
                text: $pendingOTPInput,
                prompt: Text("Secret key").foregroundStyle(.tertiary)
            )
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .font(.body.monospaced())
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .onSubmit { applyPendingSetup() }

            if let setupError {
                Text(setupError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            DetailGroupDivider()
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    showOTPInput = false
                    pendingOTPInput = ""
                    setupError = nil
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                Button("Add Code") {
                    applyPendingSetup()
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(pendingOTPInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        } else {
            DetailGroupDivider()
            DetailGroupActionRow(title: "Set Up Code…") {
                showOTPInput = true
                setupError = nil
            }
        }
    }

    @ViewBuilder
    private func configuredEditContent(setupURL: String) -> some View {
        Group {
            if let otpInfo {
                configuredCodeCard(otpInfo: otpInfo, setupURL: setupURL)
            } else if isLoading {
                DetailGroupRow(label: "Code", value: "…")
            } else if let errorMessage {
                DetailGroupRow(label: "Code", value: "—")
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                configuredActions(setupURL: setupURL)
            } else {
                DetailGroupRow(label: "Code", value: "…")
            }
        }
        .task(id: setupURL) {
            await loadOTP()
        }
    }

    @ViewBuilder
    private func configuredCodeCard(otpInfo: OTPInfo, setupURL: String?) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let code = TOTPGenerator.generateCode(from: otpInfo, at: context.date)
            let remaining = TOTPGenerator.remainingSeconds(at: context.date, period: otpInfo.period)
            // Apple Passwords: ring starts empty and fills as the period elapses.
            let fraction = 1 - (remaining / TimeInterval(otpInfo.period))

            HStack(spacing: 10) {
                Text("Code")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                OTPCountdownRing(progress: fraction)

                CopyableValueText(
                    value: TOTPGenerator.formattedDisplayCode(code),
                    isMonospaced: true,
                    lineLimit: 1,
                    feedbackScope: "\(entryName)-otp",
                    onCopy: { appState.clipboard.copy(code, showToast: false) }
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }

        if isEditing {
            DetailGroupDivider()
            configuredActions(setupURL: setupURL)
        }
    }

    @ViewBuilder
    private func configuredActions(setupURL: String?) -> some View {
        HStack(spacing: 8) {
            Spacer()
            if let setupURL {
                Button("Copy Setup URL") {
                    appState.clipboard.copy(setupURL)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            }
            Button("Delete Code…") {
                showDeleteConfirm = true
            }
            .buttonStyle(.bordered)
            .tint(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func applyPendingSetup() {
        do {
            let uri = try TOTPGenerator.makeOTPAuthURI(
                fromSetupInput: pendingOTPInput,
                account: entryName
            )
            otpauthLine = uri
            pendingOTPInput = ""
            showOTPInput = false
            setupError = nil
            errorMessage = nil
            Task { await loadOTP(otpauthLineOverride: uri) }
        } catch {
            setupError = error.localizedDescription
        }
    }

    private func loadOTP(otpauthLineOverride: String? = nil) async {
        guard !appState.appLock.isBlocking else { return }
        let line = otpauthLineOverride ?? effectiveOTPAuthLine
        guard line != nil || hasOTPMarker else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            otpInfo = try await OTPInfoLoader.resolve(
                entryName: entryName,
                otpauthLine: line,
                otpService: appState.otp
            )
        } catch {
            errorMessage = error.localizedDescription
            otpInfo = nil
        }
    }
}

private struct OTPCountdownRing: View {
    /// Elapsed fraction of the TOTP period (0 = just refreshed, 1 = about to expire).
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                // Start at 12 o’clock and fill counter-clockwise.
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
}
