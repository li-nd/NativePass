import Foundation

enum OTPInfoLoader {
    /// Prefer the decrypted `otpauth://` line; fall back to pass-otp CLI when needed.
    static func resolve(
        entryName: String,
        otpauthLine: String?,
        otpService: OTPService?
    ) async throws -> OTPInfo {
        if let uri = otpauthLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !uri.isEmpty {
            return try TOTPGenerator.parseOTPAuthURI(uri)
        }

        guard let otpService else {
            throw PassError.parseFailed(
                "OTP is configured for \"\(entryName)\" but the secret could not be read. Install pass-otp with brew install pass-otp."
            )
        }

        return try await otpService.fetchOTPInfo(for: entryName)
    }
}
