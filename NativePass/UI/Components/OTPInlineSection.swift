import SwiftUI

struct OTPInlineSection: View {
    @Environment(AppState.self) private var appState
    let entryName: String

    @State private var otpInfo: OTPInfo?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verification Code")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let otpInfo {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let code = TOTPGenerator.generateCode(from: otpInfo, at: context.date)
                    let remaining = otpRemainingSeconds(at: context.date, period: TimeInterval(otpInfo.period))
                    let progress = 1 - (remaining / TimeInterval(otpInfo.period))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(code)
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                            .textSelection(.enabled)

                        ProgressView(value: progress)
                            .progressViewStyle(.linear)

                        HStack {
                            Text("Refreshes in \(Int(ceil(remaining)))s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Copy") {
                                appState.clipboard.copy(code)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .task(id: entryName) {
            await loadOTP()
        }
    }

    private func otpRemainingSeconds(at date: Date, period: TimeInterval) -> TimeInterval {
        let epoch = date.timeIntervalSince1970
        return period - (epoch.truncatingRemainder(dividingBy: period))
    }

    private func loadOTP() async {
        guard let otp = appState.otp else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            otpInfo = try await otp.fetchOTPInfo(for: entryName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
