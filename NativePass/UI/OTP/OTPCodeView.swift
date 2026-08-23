import Combine
import SwiftUI

struct OTPCodeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let entryName: String

    @State private var otpInfo: OTPInfo?
    @State private var fallbackCode: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Text(entryName)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if isLoading {
                ProgressView("Loading OTP…")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await loadOTP() }
                }
            } else if let otpInfo {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let code = TOTPGenerator.generateCode(from: otpInfo, at: context.date)
                    let remaining = otpRemainingSeconds(at: context.date, period: TimeInterval(otpInfo.period))
                    let progress = 1 - (remaining / TimeInterval(otpInfo.period))

                    VStack(spacing: 16) {
                        Text(code)
                            .font(.system(size: 48, weight: .semibold, design: .monospaced))
                            .textSelection(.enabled)

                        ProgressView(value: progress)
                            .progressViewStyle(.linear)

                        Text("Refreshes in \(Int(ceil(remaining)))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("Copy") {
                        let code = TOTPGenerator.generateCode(from: otpInfo)
                        appState.clipboard.copy(code)
                    }
                }
            } else if let fallbackCode {
                Text(fallbackCode)
                    .font(.system(size: 48, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)

                HStack {
                    Button("Copy") {
                        appState.clipboard.copy(fallbackCode)
                    }
                    Button("Refresh") {
                        Task { await loadOTP() }
                    }
                }
            }

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 280)
        .task {
            await loadOTP()
        }
    }

    private func otpRemainingSeconds(at date: Date, period: TimeInterval) -> TimeInterval {
        let epoch = date.timeIntervalSince1970
        return period - (epoch.truncatingRemainder(dividingBy: period))
    }

    private func loadOTP() async {
        guard !appState.appLock.isBlocking else { return }

        isLoading = true
        errorMessage = nil
        otpInfo = nil
        fallbackCode = nil
        defer { isLoading = false }

        do {
            let entry = try await appState.loadEntry(entryName)
            otpInfo = try await OTPInfoLoader.resolve(
                entryName: entryName,
                otpauthLine: entry.otpauthLine,
                otpService: appState.otp
            )
        } catch {
            if let otp = appState.otp {
                do {
                    fallbackCode = try await otp.generateCode(for: entryName)
                    return
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
            errorMessage = error.localizedDescription
        }
    }
}
