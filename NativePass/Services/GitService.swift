import Foundation

struct GitService: Sendable {
    let cli: PassCLI

    private static let statusTimeout: TimeInterval = 5
    private static let syncTimeout: TimeInterval = 120
    private static let historyTimeout: TimeInterval = 30

    func status() async throws -> GitStatus {
        let porcelain = try await cli.git(["status", "--porcelain"], timeout: Self.statusTimeout)
        let branchOutput = try? await cli.git(
            ["rev-parse", "--abbrev-ref", "HEAD"],
            timeout: Self.statusTimeout
        )
        let branch = branchOutput?.trimmingCharacters(in: .whitespacesAndNewlines)
        let changedFiles = GitPorcelainParser.parse(porcelain)

        let upstream = await currentUpstream()
        var ahead = 0
        var behind = 0
        if upstream != nil {
            ahead = await count(["rev-list", "--count", "@{u}..HEAD"])
            behind = await count(["rev-list", "--count", "HEAD..@{u}"])
        }

        return GitStatus(
            branch: branch,
            upstream: upstream,
            isClean: changedFiles.isEmpty,
            changedFiles: changedFiles,
            aheadCount: ahead,
            behindCount: behind,
            porcelainOutput: porcelain
        )
    }

    func pull() async throws {
        _ = try await cli.git(["pull"], timeout: Self.syncTimeout)
    }

    func push() async throws {
        _ = try await cli.git(["push"], timeout: Self.syncTimeout)
    }

    /// First push that also sets upstream tracking (`git push -u <remote> HEAD`).
    func pushSetUpstream(remote: String = "origin") async throws {
        let name = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw PassError.parseFailed(String(localized: "Remote name is empty."))
        }
        _ = try await cli.git(["push", "-u", name, "HEAD"], timeout: Self.syncTimeout)
    }

    func listRemotes() async throws -> [GitRemote] {
        let output = try await cli.git(["remote", "-v"], timeout: Self.statusTimeout)
        return GitRemoteParser.parse(output)
    }

    func addRemote(name: String, url: String) async throws {
        let remoteName = try normalizedRemoteName(name)
        let remoteURL = try normalizedRemoteURL(url)
        _ = try await cli.git(["remote", "add", remoteName, remoteURL], timeout: Self.statusTimeout)
    }

    func setRemoteURL(name: String, url: String) async throws {
        let remoteName = try normalizedRemoteName(name)
        let remoteURL = try normalizedRemoteURL(url)
        _ = try await cli.git(["remote", "set-url", remoteName, remoteURL], timeout: Self.statusTimeout)
    }

    func removeRemote(name: String) async throws {
        let remoteName = try normalizedRemoteName(name)
        _ = try await cli.git(["remote", "remove", remoteName], timeout: Self.statusTimeout)
    }

    /// Remote-tracking refs like `origin/main` (excludes `origin/HEAD`).
    func listRemoteBranches() async throws -> [String] {
        let output = try await cli.git(["branch", "-r", "--format=%(refname:short)"], timeout: Self.statusTimeout)
        return output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasSuffix("/HEAD") && !$0.contains(" -> ") }
            .sorted()
    }

    func setUpstream(_ remoteBranch: String) async throws {
        let ref = remoteBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else {
            throw PassError.parseFailed(String(localized: "Upstream branch is empty."))
        }
        _ = try await cli.git(
            ["branch", "--set-upstream-to=\(ref)"],
            timeout: Self.statusTimeout
        )
    }

    func unsetUpstream() async throws {
        _ = try await cli.git(["branch", "--unset-upstream"], timeout: Self.statusTimeout)
    }

    func fetch(remote: String? = nil) async throws {
        var args = ["fetch"]
        if let remote {
            let name = try normalizedRemoteName(remote)
            args.append(name)
        }
        _ = try await cli.git(args, timeout: Self.syncTimeout)
    }

    private func normalizedRemoteName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PassError.parseFailed(String(localized: "Remote name is empty."))
        }
        return trimmed
    }

    private func normalizedRemoteURL(_ url: String) throws -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PassError.parseFailed(String(localized: "Remote URL is empty."))
        }
        return trimmed
    }

    /// Commit history for a pass entry (follows renames).
    func revisions(forEntry name: String) async throws -> [EntryRevision] {
        let relativePath = Self.gpgRelativePath(forEntry: name)
        let output = try await cli.git(
            [
                "log",
                "--follow",
                "--pretty=format:%H%x00%aI%x00%s%x00",
                "--name-only",
                "--",
                relativePath,
            ],
            timeout: Self.historyTimeout
        )
        return Self.parseRevisionLog(output, fallbackPath: relativePath)
    }

    static func gpgRelativePath(forEntry name: String) -> String {
        name.hasSuffix(".gpg") ? name : "\(name).gpg"
    }

    // MARK: - Private

    private func currentUpstream() async -> String? {
        do {
            let output = try await cli.git(
                ["rev-parse", "--abbrev-ref", "@{u}"],
                timeout: Self.statusTimeout
            )
            let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        } catch {
            return nil
        }
    }

    private func count(_ args: [String]) async -> Int {
        guard let output = try? await cli.git(args, timeout: Self.statusTimeout) else { return 0 }
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    /// Parses `git log --follow --pretty=format:… --name-only` output.
    static func parseRevisionLog(_ output: String, fallbackPath: String) -> [EntryRevision] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFraction = ISO8601DateFormatter()
        isoFormatterNoFraction.formatOptions = [.withInternetDateTime]

        var revisions: [EntryRevision] = []
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0

        while index < lines.count {
            let line = lines[index]
            index += 1

            guard line.contains("\0") else { continue }

            let parts = line.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { continue }

            let hash = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let dateRaw = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let subject = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard hash.count >= 7 else { continue }

            while index < lines.count && lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                index += 1
            }

            var path = fallbackPath
            if index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.hasSuffix(".gpg") {
                    path = candidate
                    index += 1
                }
            }

            let date = isoFormatter.date(from: dateRaw)
                ?? isoFormatterNoFraction.date(from: dateRaw)
                ?? Date()

            revisions.append(
                EntryRevision(
                    commitHash: hash,
                    shortHash: String(hash.prefix(7)),
                    authoredDate: date,
                    subject: subject.isEmpty ? String(localized: "Commit") : subject,
                    relativeGPGPath: path
                )
            )
        }

        return revisions
    }
}
