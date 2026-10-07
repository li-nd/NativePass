import Foundation

struct GPGKeyInfo: Identifiable, Hashable, Sendable {
    var id: String { fingerprint.isEmpty ? keyID : fingerprint }
    let keyID: String
    let fingerprint: String
    let userIDs: [String]
    let hasSecret: Bool

    var primaryUserID: String {
        userIDs.first ?? keyID
    }

    var shortLabel: String {
        if let uid = userIDs.first, !uid.isEmpty {
            return uid
        }
        if fingerprint.count >= 16 {
            return String(fingerprint.suffix(16))
        }
        return keyID
    }

    var detailLabel: String {
        let uid = primaryUserID
        let short = keyID.count > 8 ? String(keyID.suffix(8)) : keyID
        if uid == keyID || uid.isEmpty {
            return short
        }
        return "\(uid) (\(short))"
    }

    /// Values suitable for `pass init` (prefer fingerprint, else key id).
    var passInitID: String {
        if fingerprint.count >= 16 {
            return fingerprint
        }
        return keyID
    }
}

enum GPGKeyListing {
    static func listSecretKeys(
        gpgBinary: String = "gpg",
        environment: [String: String]? = nil
    ) -> [GPGKeyInfo] {
        listKeys(secret: true, gpgBinary: gpgBinary, environment: environment)
    }

    static func displayLabels(
        for ids: [String],
        gpgBinary: String = "gpg",
        environment: [String: String]? = nil
    ) -> [String: String] {
        let secrets = listSecretKeys(gpgBinary: gpgBinary, environment: environment)
        let publics = listKeys(secret: false, gpgBinary: gpgBinary, environment: environment)
        let all = secrets + publics
        var map: [String: String] = [:]
        for id in ids {
            if let match = all.first(where: { matches($0, id: id) }) {
                map[id] = match.detailLabel
            } else {
                map[id] = id
            }
        }
        return map
    }

    static func matches(_ key: GPGKeyInfo, id: String) -> Bool {
        let needle = id.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !needle.isEmpty else { return false }
        if key.fingerprint.uppercased() == needle { return true }
        if key.fingerprint.uppercased().hasSuffix(needle) { return true }
        if key.keyID.uppercased() == needle { return true }
        if key.keyID.uppercased().hasSuffix(needle) { return true }
        if key.userIDs.contains(where: { $0.caseInsensitiveCompare(id) == .orderedSame }) {
            return true
        }
        if key.userIDs.contains(where: { $0.localizedCaseInsensitiveContains(id) }) {
            return true
        }
        return false
    }

    // MARK: - Private

    private static func listKeys(
        secret: Bool,
        gpgBinary: String,
        environment: [String: String]?
    ) -> [GPGKeyInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            gpgBinary,
            secret ? "--list-secret-keys" : "--list-keys",
            "--with-colons",
            "--fixed-list-mode",
        ]
        if let environment {
            process.environment = environment
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            return parseColonListing(output, hasSecret: secret)
        } catch {
            return []
        }
    }

    /// Parses GnuPG `--with-colons` listing into keys.
    static func parseColonListing(_ output: String, hasSecret: Bool) -> [GPGKeyInfo] {
        var keys: [GPGKeyInfo] = []
        var currentKeyID = ""
        var currentFingerprint = ""
        var currentUIDs: [String] = []
        var inPrimary = false

        func flush() {
            guard inPrimary, !currentKeyID.isEmpty || !currentFingerprint.isEmpty else {
                currentKeyID = ""
                currentFingerprint = ""
                currentUIDs = []
                inPrimary = false
                return
            }
            keys.append(
                GPGKeyInfo(
                    keyID: currentKeyID,
                    fingerprint: currentFingerprint,
                    userIDs: currentUIDs,
                    hasSecret: hasSecret
                )
            )
            currentKeyID = ""
            currentFingerprint = ""
            currentUIDs = []
            inPrimary = false
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let fields = line.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard let type = fields.first else { continue }
            switch type {
            case "sec", "pub":
                flush()
                inPrimary = true
                if fields.count > 4 {
                    currentKeyID = fields[4]
                }
            case "fpr" where inPrimary:
                // Fingerprint field is index 9 in colon format.
                if fields.count > 9, currentFingerprint.isEmpty {
                    currentFingerprint = fields[9]
                }
            case "uid" where inPrimary:
                if fields.count > 9 {
                    let uid = fields[9].trimmingCharacters(in: .whitespaces)
                    if !uid.isEmpty {
                        currentUIDs.append(uid)
                    }
                }
            case "ssb", "sub":
                // Ignore subkeys for listing primary recipients.
                break
            default:
                break
            }
        }
        flush()
        return keys
    }
}
