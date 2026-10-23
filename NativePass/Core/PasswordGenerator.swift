import Foundation
import Security

struct PasswordGeneratorOptions: Equatable, Sendable {
    var length: Int
    var includeUppercase: Bool
    var includeLowercase: Bool
    var includeDigits: Bool
    var includeSymbols: Bool
    var avoidAmbiguous: Bool

    static let minimumLength = 8
    static let maximumLength = 128

    static var `default`: PasswordGeneratorOptions {
        PasswordGeneratorOptions(
            length: AppPreferences.defaultPasswordLength,
            includeUppercase: true,
            includeLowercase: true,
            includeDigits: true,
            includeSymbols: true,
            avoidAmbiguous: false
        )
    }

    var clampedLength: Int {
        min(max(length, Self.minimumLength), Self.maximumLength)
    }

    var hasAnyCharset: Bool {
        includeUppercase || includeLowercase || includeDigits || includeSymbols
    }
}

enum PasswordGenerator {
    private static let uppercase = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
    private static let digits = Array("0123456789")
    private static let symbols = Array("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
    private static let ambiguous: Set<Character> = Set("0OolI1|")

    static func generate(options: PasswordGeneratorOptions) throws -> String {
        let length = options.clampedLength
        let pools = characterPools(for: options)
        guard !pools.isEmpty else {
            throw PassError.parseFailed(String(localized: "Select at least one character set."))
        }

        let combined = pools.flatMap { $0 }
        guard !combined.isEmpty else {
            throw PassError.parseFailed(String(localized: "Character set is empty."))
        }

        var characters: [Character] = []
        characters.reserveCapacity(length)

        // Guarantee at least one character from each selected pool when length allows.
        if length >= pools.count {
            for pool in pools {
                characters.append(pool[try randomIndex(upperBound: pool.count)])
            }
        }

        while characters.count < length {
            characters.append(combined[try randomIndex(upperBound: combined.count)])
        }

        try shuffle(&characters)
        return String(characters)
    }

    /// Convenience using stored preferences.
    static func generate() throws -> String {
        try generate(options: AppPreferences.passwordGeneratorOptions)
    }

    private static func characterPools(for options: PasswordGeneratorOptions) -> [[Character]] {
        var pools: [[Character]] = []
        if options.includeUppercase {
            pools.append(filter(uppercase, avoidAmbiguous: options.avoidAmbiguous))
        }
        if options.includeLowercase {
            pools.append(filter(lowercase, avoidAmbiguous: options.avoidAmbiguous))
        }
        if options.includeDigits {
            pools.append(filter(digits, avoidAmbiguous: options.avoidAmbiguous))
        }
        if options.includeSymbols {
            pools.append(filter(symbols, avoidAmbiguous: options.avoidAmbiguous))
        }
        return pools.filter { !$0.isEmpty }
    }

    private static func filter(_ source: [Character], avoidAmbiguous: Bool) -> [Character] {
        guard avoidAmbiguous else { return source }
        return source.filter { !ambiguous.contains($0) }
    }

    private static func shuffle(_ characters: inout [Character]) throws {
        guard characters.count > 1 else { return }
        for index in stride(from: characters.count - 1, through: 1, by: -1) {
            let j = try randomIndex(upperBound: index + 1)
            characters.swapAt(index, j)
        }
    }

    private static func randomIndex(upperBound: Int) throws -> Int {
        guard upperBound > 1 else { return 0 }

        let bound = UInt32(upperBound)
        // Largest multiple of `bound` that fits in UInt32 — avoids the classic
        // `UInt32.max - (UInt32.max % bound) + 1` overflow (wraps to 0 → infinite loop
        // when `bound` divides UInt32.max, e.g. 3, 5, 15, 17 during Fisher–Yates).
        let limit = (UInt32.max / bound) * bound
        var randomValue = UInt32(0)
        repeat {
            let status = SecRandomCopyBytes(
                kSecRandomDefault,
                MemoryLayout<UInt32>.size,
                &randomValue
            )
            guard status == errSecSuccess else {
                throw PassError.parseFailed(String(localized: "Failed to generate secure random bytes."))
            }
        } while randomValue >= limit

        return Int(randomValue % bound)
    }
}
