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
        let changedLines = porcelain.split(separator: "\n").filter { !$0.isEmpty }

        let hasUpstream = await checkUpstream()
        var ahead = 0
        var behind = 0
        if hasUpstream {
            ahead = await count(["rev-list", "--count", "@{u}..HEAD"])
            behind = await count(["rev-list", "--count", "HEAD..@{u}"])
        }

        return GitStatus(
            branch: branch,
            isClean: changedLines.isEmpty,
            changedFilesCount: changedLines.count,
            aheadCount: ahead,
            behindCount: behind,
            hasUpstream: hasUpstream,
            porcelainOutput: porcelain
        )
    }

    func pull() async throws {
        _ = try await cli.git(["pull"], timeout: Self.syncTimeout)
    }

    func push() async throws {
        _ = try await cli.git(["push"], timeout: Self.syncTimeout)
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

    private func checkUpstream() async -> Bool {
        do {
            _ = try await cli.git(
                ["rev-parse", "--abbrev-ref", "@{u}"],
                timeout: Self.statusTimeout
            )
            return true
        } catch {
            return false
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
