import Foundation

enum DecryptFailureAnalyzer {
    static func analyze(
        error: Error,
        entryName: String,
        environment: PassEnvironment
    ) -> DecryptRecoveryGuide {
        let rawError = error.localizedDescription
        let stderr = extractStderr(from: error) ?? rawError
        let normalized = stderr.lowercased()

        if normalized.contains("cancelled by user") || normalized.contains("canceled by user") {
            return userCancelledGuide(rawError: rawError, entryName: entryName, environment: environment)
        }

        if environment.pinentryProgram == nil,
           matchesPinentryIssue(normalized) {
            return pinentryGuide(rawError: rawError, entryName: entryName, environment: environment)
        }

        if normalized.contains("gpg-agent") || normalized.contains("agent ipc") {
            return agentGuide(rawError: rawError, entryName: entryName, environment: environment)
        }

        if normalized.contains("no secret key") || normalized.contains("public key decryption failed") {
            if hasMatchingSecretKey(gpgBinary: environment.gpgBinary, gpgIDs: environment.gpgIDs) {
                return keyLockedGuide(rawError: rawError, entryName: entryName, environment: environment)
            }
            return keyMissingGuide(rawError: rawError, environment: environment)
        }

        if environment.pinentryProgram == nil {
            return pinentryGuide(rawError: rawError, entryName: entryName, environment: environment)
        }

        return unknownGuide(rawError: rawError, entryName: entryName, environment: environment)
    }

    // MARK: - Guides

    private static func pinentryGuide(
        rawError: String,
        entryName: String,
        environment: PassEnvironment
    ) -> DecryptRecoveryGuide {
        let pinentryPath = suggestedPinentryPath()
        let quotedEntry = shellQuote(entryName)

        return DecryptRecoveryGuide(
            kind: .pinentryNotConfigured,
            title: String(localized: "Password Prompt Not Configured"),
            explanation: String(localized: "NativePass runs GPG in the background and cannot show a terminal password prompt. Install pinentry-mac so GPG can ask for your passphrase in a macOS dialog."),
            steps: [
                RecoveryStep(
                    title: String(localized: "Install pinentry-mac"),
                    command: "brew install pinentry-mac"
                ),
                RecoveryStep(
                    title: String(localized: "Add pinentry to GPG agent config"),
                    detail: String(localized: "Append this line to ~/.gnupg/gpg-agent.conf"),
                    command: "pinentry-program \(pinentryPath)"
                ),
                RecoveryStep(
                    title: String(localized: "Restart the GPG agent"),
                    command: "gpgconf --kill gpg-agent"
                ),
                RecoveryStep(
                    title: String(localized: "Unlock your key in Terminal"),
                    detail: String(localized: "Enter your GPG passphrase when prompted, then try again in NativePass."),
                    command: "pass show \(quotedEntry)"
                ),
            ],
            rawError: rawError,
            gpgRecipientIDs: environment.gpgIDs
        )
    }

    private static func keyLockedGuide(
        rawError: String,
        entryName: String,
        environment: PassEnvironment
    ) -> DecryptRecoveryGuide {
        let quotedEntry = shellQuote(entryName)
        var steps = [
            RecoveryStep(
                title: String(localized: "Unlock your GPG key in Terminal"),
                detail: String(localized: "Enter your passphrase when prompted."),
                command: "pass show \(quotedEntry)"
            ),
            RecoveryStep(
                title: String(localized: "Try again in NativePass"),
                detail: String(localized: "After unlocking, press Try Again below.")
            ),
        ]

        if environment.pinentryProgram == nil {
            steps.insert(
                RecoveryStep(
                    title: String(localized: "Configure pinentry-mac for in-app prompts"),
                    detail: String(localized: "Without this, NativePass cannot show a passphrase dialog."),
                    command: "brew install pinentry-mac"
                ),
                at: 0
            )
        }

        return DecryptRecoveryGuide(
            kind: .keyLocked,
            title: String(localized: "GPG Key Needs to Be Unlocked"),
            explanation: String(localized: "Your private key is present but locked. Unlock it once in Terminal, or configure pinentry-mac so NativePass can prompt for your passphrase."),
            steps: steps,
            rawError: rawError,
            gpgRecipientIDs: environment.gpgIDs
        )
    }

    private static func keyMissingGuide(
        rawError: String,
        environment: PassEnvironment
    ) -> DecryptRecoveryGuide {
        let recipientDetail: String
        if environment.gpgIDs.isEmpty {
            recipientDetail = String(localized: "Check ~/.password-store/.gpg-id for the expected recipient.")
        } else {
            recipientDetail = String(localized: "Expected recipient: \(environment.gpgIDs.joined(separator: ", "))")
        }

        return DecryptRecoveryGuide(
            kind: .keyMissing,
            title: String(localized: "Private Key Not Found"),
            explanation: String(localized: "This password store is encrypted for a GPG key that is not available on this Mac. Import the matching private key or use the machine where the key already exists."),
            steps: [
                RecoveryStep(
                    title: String(localized: "Check available secret keys"),
                    detail: recipientDetail,
                    command: "gpg --list-secret-keys --keyid-format=long"
                ),
                RecoveryStep(
                    title: String(localized: "Import your private key"),
                    detail: String(localized: "Replace the path with your exported secret key file."),
                    command: "gpg --import ~/path/to/private-key.asc"
                ),
            ],
            rawError: rawError,
            gpgRecipientIDs: environment.gpgIDs
        )
    }

    private static func userCancelledGuide(
        rawError: String,
        entryName: String,
        environment: PassEnvironment
    ) -> DecryptRecoveryGuide {
        DecryptRecoveryGuide(
            kind: .userCancelled,
            title: String(localized: "Passphrase Entry Cancelled"),
            explanation: String(localized: "GPG did not receive a passphrase. Try again when you're ready to unlock your key."),
            steps: [
                RecoveryStep(
                    title: String(localized: "Unlock in Terminal"),
                    command: "pass show \(shellQuote(entryName))"
                ),
            ],
            rawError: rawError,
            gpgRecipientIDs: environment.gpgIDs
        )
    }

    private static func agentGuide(
        rawError: String,
        entryName: String,
        environment: PassEnvironment
    ) -> DecryptRecoveryGuide {
        DecryptRecoveryGuide(
            kind: .agentUnavailable,
            title: String(localized: "GPG Agent Unavailable"),
            explanation: String(localized: "The GPG agent is not running or cannot be reached. Restart it and try again."),
            steps: [
                RecoveryStep(
                    title: String(localized: "Restart the GPG agent"),
                    command: "gpgconf --kill gpg-agent"
                ),
                RecoveryStep(
                    title: String(localized: "Test decryption in Terminal"),
                    command: "pass show \(shellQuote(entryName))"
                ),
            ],
            rawError: rawError,
            gpgRecipientIDs: environment.gpgIDs
        )
    }

    private static func unknownGuide(
        rawError: String,
        entryName: String,
        environment: PassEnvironment
    ) -> DecryptRecoveryGuide {
        DecryptRecoveryGuide(
            kind: .unknown,
            title: String(localized: "Could Not Decrypt Entry"),
            explanation: String(localized: "GPG could not decrypt this entry. Try the steps below or open Diagnostics for more details."),
            steps: [
                RecoveryStep(
                    title: String(localized: "Test in Terminal"),
                    command: "pass show \(shellQuote(entryName))"
                ),
                RecoveryStep(
                    title: String(localized: "List secret keys"),
                    command: "gpg --list-secret-keys --keyid-format=long"
                ),
            ],
            rawError: rawError,
            gpgRecipientIDs: environment.gpgIDs
        )
    }

    // MARK: - Helpers

    private static func extractStderr(from error: Error) -> String? {
        guard case PassError.commandFailed(_, let stderr) = error else { return nil }
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func matchesPinentryIssue(_ normalized: String) -> Bool {
        normalized.contains("no secret key")
            || normalized.contains("inappropriate ioctl")
            || normalized.contains("cannot open '/dev/tty'")
            || normalized.contains("no pinentry")
            || normalized.contains("pinentry")
    }

    static func suggestedPinentryPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/pinentry-mac",
            "/usr/local/bin/pinentry-mac",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return candidates[0]
    }

    static func hasMatchingSecretKey(gpgBinary: String, gpgIDs: [String]) -> Bool {
        guard !gpgIDs.isEmpty else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [gpgBinary, "--list-secret-keys", "--keyid-format=long"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self).lowercased()
            return gpgIDs.contains { id in
                let normalizedID = id.lowercased()
                return output.contains(normalizedID)
            }
        } catch {
            return false
        }
    }

    private static func shellQuote(_ value: String) -> String {
        if value.range(of: #"[\s'"\\$`!]"#, options: .regularExpression) == nil {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
