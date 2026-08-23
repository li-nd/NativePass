import Foundation
import CryptoKit

struct OTPInfo: Sendable {
    let secret: Data
    let digits: Int
    let period: Int
    let algorithm: OTPAlgorithm
}

enum OTPAlgorithm: Sendable {
    case sha1
    case sha256
    case sha512
}

enum TOTPGenerator {
    static func generateCode(from info: OTPInfo, at date: Date = Date()) -> String {
        let counter = UInt64(date.timeIntervalSince1970) / UInt64(info.period)
        var counterBE = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBE) { Data($0) }

        let hash: Data
        switch info.algorithm {
        case .sha1:
            hash = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: SymmetricKey(data: info.secret)))
        case .sha256:
            hash = Data(HMAC<SHA256>.authenticationCode(for: counterData, using: SymmetricKey(data: info.secret)))
        case .sha512:
            hash = Data(HMAC<SHA512>.authenticationCode(for: counterData, using: SymmetricKey(data: info.secret)))
        }

        let offset = Int(hash[hash.count - 1] & 0x0F)
        let truncated = hash.withUnsafeBytes { ptr -> UInt32 in
            let slice = ptr.baseAddress!.advanced(by: offset)
            let value = slice.loadUnaligned(as: UInt32.self)
            return UInt32(bigEndian: value) & 0x7FFF_FFFF
        }
        let modulus = UInt32(pow(10.0, Double(info.digits)))
        return String(format: "%0*u", info.digits, truncated % modulus)
    }

    static func parseOTPAuthURI(_ uri: String) throws -> OTPInfo {
        guard let components = URLComponents(string: uri.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "otpauth",
              components.host == "totp" else {
            throw PassError.parseFailed("otpauth URI")
        }
        guard let secretParam = components.queryItems?.first(where: { $0.name == "secret" })?.value,
              let secret = base32Decode(secretParam) else {
            throw PassError.parseFailed("otpauth secret")
        }
        let digits = Int(components.queryItems?.first(where: { $0.name == "digits" })?.value ?? "6") ?? 6
        let period = Int(components.queryItems?.first(where: { $0.name == "period" })?.value ?? "30") ?? 30
        let algoName = components.queryItems?.first(where: { $0.name == "algorithm" })?.value?.uppercased() ?? "SHA1"
        let algorithm: OTPAlgorithm
        switch algoName {
        case "SHA256": algorithm = .sha256
        case "SHA512": algorithm = .sha512
        default: algorithm = .sha1
        }
        return OTPInfo(secret: secret, digits: digits, period: period, algorithm: algorithm)
    }

    private static func base32Decode(_ string: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0
        var value = 0
        var output = Data()
        for char in string.uppercased().filter({ $0 != "=" }) {
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            value = (value << 5) | index
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((value >> bits) & 0xFF))
            }
        }
        return output
    }
}
