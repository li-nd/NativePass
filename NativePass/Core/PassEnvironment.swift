import Foundation

struct PassEnvironment: Sendable {
    let passBinary: URL?
    let passVersion: String?
    let systemExtensionDirectory: URL?
    let extensionDirectories: [URL]
    let userExtensionDirectory: URL
    let storeDirectory: URL
    let gpgBinary: String
    let gpgVersion: String?
    let gpgIDs: [String]
    let isStoreInitialized: Bool
    let isGitRepository: Bool
    let pinentryProgram: String?

    var isPassAvailable: Bool { passBinary != nil }

    static let defaultStorePath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".password-store", isDirectory: true)
    }()

    static let knownSystemExtensionDirectories: [URL] = [
        URL(fileURLWithPath: "/opt/homebrew/lib/password-store/extensions", isDirectory: true),
        URL(fileURLWithPath: "/usr/local/lib/password-store/extensions", isDirectory: true),
    ]

    static func detect(storeDirectory: URL? = nil) -> PassEnvironment {
        let store = storeDirectory ?? loadStoreDirectoryFromDefaults() ?? defaultStorePath
        let passBinary = locatePassBinary()
        let gpgBinary = locateBinary(named: "gpg", candidates: [
            "/opt/homebrew/bin/gpg",
            "/usr/local/bin/gpg",
            "/opt/homebrew/bin/gpg2",
            "/usr/local/bin/gpg2",
        ])?.lastPathComponent ?? "gpg"

        let systemExtensionDir = resolveSystemExtensionDirectory(passBinary: passBinary)
        let userExtensionDir = store.appendingPathComponent(".extensions", isDirectory: true)
        let extensionDirs = resolveExtensionDirectories(
            store: store,
            systemExtensionDirectory: systemExtensionDir,
            userExtensionDirectory: userExtensionDir
        )
        let passVersion = passBinary.flatMap { parsePassVersion(from: $0) }
        let gpgHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gnupg", isDirectory: true)
        let pinentry = readPinentryProgram(gpgHome: gpgHome)
        let gpgIDs = readGPGIDs(store: store)
        let isInitialized = FileManager.default.fileExists(
            atPath: store.appendingPathComponent(".gpg-id").path
        )
        let isGit = FileManager.default.fileExists(
            atPath: store.appendingPathComponent(".git").path
        )

        return PassEnvironment(
            passBinary: passBinary,
            passVersion: passVersion,
            systemExtensionDirectory: systemExtensionDir,
            extensionDirectories: extensionDirs,
            userExtensionDirectory: userExtensionDir,
            storeDirectory: store,
            gpgBinary: gpgBinary,
            gpgVersion: readGPGVersion(binary: gpgBinary),
            gpgIDs: gpgIDs,
            isStoreInitialized: isInitialized,
            isGitRepository: isGit,
            pinentryProgram: pinentry
        )
    }

    func processEnvironment() -> [String: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var env: [String: String] = [
            "HOME": home,
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "PASSWORD_STORE_DIR": storeDirectory.path,
            "PASSWORD_STORE_ENABLE_EXTENSIONS": "true",
            "GNUPGHOME": "\(home)/.gnupg",
        ]
        // User extensions live under the store; do not point this at the system dir.
        env["PASSWORD_STORE_EXTENSIONS_DIR"] = userExtensionDirectory.path
        return env
    }

    func environmentSnapshot() -> [String: String] {
        var snapshot = processEnvironment()
        if let passBinary {
            snapshot["PASS_BINARY"] = passBinary.path
        }
        if let systemExtensionDirectory {
            snapshot["SYSTEM_EXTENSION_DIR"] = systemExtensionDirectory.path
        }
        snapshot["USER_EXTENSION_DIR"] = userExtensionDirectory.path
        snapshot["EXTENSION_DIRS"] = extensionDirectories.map(\.path).joined(separator: ":")
        return snapshot.sorted { $0.key < $1.key }.reduce(into: [:]) { $0[$1.key] = $1.value }
    }

    func isEquivalent(to other: PassEnvironment) -> Bool {
        passBinary == other.passBinary
            && systemExtensionDirectory == other.systemExtensionDirectory
            && extensionDirectories == other.extensionDirectories
            && storeDirectory == other.storeDirectory
            && isGitRepository == other.isGitRepository
            && isStoreInitialized == other.isStoreInitialized
    }

    static func saveStoreDirectory(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "storeDirectory")
    }

    // MARK: - Private

    private static func loadStoreDirectoryFromDefaults() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: "storeDirectory") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func locatePassBinary() -> URL? {
        var candidates: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL?) {
            guard let url else { return }
            let resolved = url.resolvingSymlinksInPath()
            let key = resolved.path
            guard !seen.contains(key) else { return }
            seen.insert(key)
            candidates.append(resolved)
        }

        append(runWhich("pass"))
        for path in ["/opt/homebrew/bin/pass", "/usr/local/bin/pass"] {
            append(URL(fileURLWithPath: path))
        }

        return candidates
            .map { (url: $0, score: scorePassBinary($0)) }
            .filter { $0.score > 0 }
            .max(by: { $0.score < $1.score })?
            .url
    }

    /// Prefer real password-store over gopass / unrelated `pass` shims.
    private static func scorePassBinary(_ url: URL) -> Int {
        guard FileManager.default.isExecutableFile(atPath: url.path) else { return 0 }
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            // Binary (e.g. gopass) — not shell password-store.
            return 0
        }

        var score = 0
        let lower = contents.lowercased()
        if lower.contains("gopass") { return 0 }
        if contents.contains("passwordstore.org") || contents.contains("password-store") {
            score += 10
        }
        if contents.contains("cmd_show") || contents.contains("cmd_extension") {
            score += 5
        }
        if PassVersionParser.parseSystemExtensionDir(from: contents) != nil {
            score += 20
        }
        if PassVersionParser.parsePassVersion(from: contents) != nil {
            score += 5
        }
        if url.path.hasPrefix("/opt/homebrew/") {
            score += 2
        }
        return score
    }

    private static func locateBinary(named name: String, candidates: [String]) -> URL? {
        if let which = runWhich(name) {
            return which
        }
        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private static func runWhich(_ name: String) -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path).resolvingSymlinksInPath()
        } catch {
            return nil
        }
    }

    private static func resolveSystemExtensionDirectory(passBinary: URL?) -> URL? {
        if let passBinary, let fromScript = parseSystemExtensionDir(from: passBinary),
           FileManager.default.fileExists(atPath: fromScript.path) {
            return fromScript
        }

        for candidate in knownSystemExtensionDirectories {
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private static func resolveExtensionDirectories(
        store: URL,
        systemExtensionDirectory: URL?,
        userExtensionDirectory: URL
    ) -> [URL] {
        var dirs: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL?) {
            guard let url else { return }
            let resolved = url.resolvingSymlinksInPath()
            let key = resolved.path
            guard !seen.contains(key) else { return }
            guard FileManager.default.fileExists(atPath: resolved.path) else { return }
            seen.insert(key)
            dirs.append(resolved)
        }

        append(systemExtensionDirectory)
        for candidate in knownSystemExtensionDirectories {
            append(candidate)
        }
        append(userExtensionDirectory)
        // Also accept the store path even if empty — discovery skips missing files.
        if !seen.contains(userExtensionDirectory.path) {
            dirs.append(userExtensionDirectory)
        }
        return dirs
    }

    private static func parseSystemExtensionDir(from passBinary: URL) -> URL? {
        guard let contents = try? String(contentsOf: passBinary, encoding: .utf8) else { return nil }
        guard let path = PassVersionParser.parseSystemExtensionDir(from: contents) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func parsePassVersion(from passBinary: URL) -> String? {
        guard let contents = try? String(contentsOf: passBinary, encoding: .utf8) else { return nil }
        return PassVersionParser.parsePassVersion(from: contents)
    }

    private static func readGPGIDs(store: URL) -> [String] {
        let gpgIDFile = store.appendingPathComponent(".gpg-id")
        guard let contents = try? String(contentsOf: gpgIDFile, encoding: .utf8) else { return [] }
        return contents
            .split(separator: "\n")
            .map { $0.split(separator: "#", maxSplits: 1).first.map(String.init) ?? "" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func readGPGVersion(binary: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [binary, "--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            return PassVersionParser.parseGPGVersion(from: output)
        } catch {
            return nil
        }
    }

    private static func readPinentryProgram(gpgHome: URL) -> String? {
        let conf = gpgHome.appendingPathComponent("gpg-agent.conf")
        guard let contents = try? String(contentsOf: conf, encoding: .utf8) else { return nil }
        return PassVersionParser.parsePinentryProgram(from: contents)
    }
}
