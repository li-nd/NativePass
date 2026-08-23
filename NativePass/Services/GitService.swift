import Foundation

struct GitService: Sendable {
    let cli: PassCLI

    private static let statusTimeout: TimeInterval = 5
    private static let syncTimeout: TimeInterval = 120

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
}
