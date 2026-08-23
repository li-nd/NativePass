import Foundation
import Security

enum PasswordGenerator {
    private static let alphanumericCharset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    private static let symbolCharset = Array("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")

    static func generate(length: Int, includeSymbols: Bool = true) throws -> String {
        guard length > 0 else {
            throw PassError.parseFailed(String(localized: "password length must be greater than zero"))
        }

        var charset = alphanumericCharset
        if includeSymbols {
            charset.append(contentsOf: symbolCharset)
        }
        guard !charset.isEmpty else {
            throw PassError.parseFailed(String(localized: "password charset is empty"))
        }

        var password = ""
        password.reserveCapacity(length)
        for _ in 0..<length {
            let index = try randomIndex(upperBound: charset.count)
            password.append(charset[index])
        }
        return password
    }

    private static func randomIndex(upperBound: Int) throws -> Int {
        guard upperBound > 1 else { return 0 }

        let bound = UInt32(upperBound)
        let limit = UInt32.max - (UInt32.max % bound) + 1
        var randomValue = UInt32(0)
        repeat {
            let status = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &randomValue)
            guard status == errSecSuccess else {
                throw PassError.parseFailed(String(localized: "failed to generate secure random bytes"))
            }
        } while randomValue >= limit

        return Int(randomValue % bound)
    }
}
