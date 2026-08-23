import Foundation
import Observation

struct OTPService: Sendable {
    let cli: PassCLI

    func generateCode(for entry: String) async throws -> String {
        let code = try await cli.runOrThrow(["otp", entry])
        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchURI(for entry: String) async throws -> String {
        try await cli.runOrThrow(["otp", "uri", entry]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchOTPInfo(for entry: String) async throws -> OTPInfo {
        let uri = try await fetchURI(for: entry)
        return try TOTPGenerator.parseOTPAuthURI(uri)
    }

    func generateCode(from info: OTPInfo, at date: Date = Date()) -> String {
        TOTPGenerator.generateCode(from: info, at: date)
    }
}
