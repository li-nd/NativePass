import Foundation
import Observation

@Observable
@MainActor
final class GitSyncState {
    private(set) var status: GitStatus?
    private(set) var remotes: [GitRemote] = []
    private(set) var remoteBranches: [String] = []
    private(set) var isSyncing = false
    private(set) var lastSynced: Date?
    private(set) var lastError: String?
    private(set) var lastMessage: String?

    func refresh(using git: GitService?) async {
        guard let git else {
            status = nil
            remotes = []
            remoteBranches = []
            return
        }
        status = try? await git.status()
        remotes = (try? await git.listRemotes()) ?? []
        remoteBranches = (try? await git.listRemoteBranches()) ?? []
    }

    func pull(using git: GitService?) async {
        guard let git else { return }
        isSyncing = true
        lastError = nil
        lastMessage = nil
        defer { isSyncing = false }
        do {
            try await git.pull()
            lastSynced = Date()
            lastMessage = String(localized: "Pull completed.")
            await refresh(using: git)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func push(using git: GitService?) async {
        guard let git else { return }
        isSyncing = true
        lastError = nil
        lastMessage = nil
        defer { isSyncing = false }
        do {
            try await git.push()
            lastSynced = Date()
            lastMessage = String(localized: "Push completed.")
            await refresh(using: git)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func pushSetUpstream(using git: GitService?, remote: String = "origin") async {
        guard let git else { return }
        isSyncing = true
        lastError = nil
        lastMessage = nil
        defer { isSyncing = false }
        do {
            try await git.pushSetUpstream(remote: remote)
            lastSynced = Date()
            lastMessage = String(localized: "Push completed and upstream set.")
            await refresh(using: git)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addRemote(using git: GitService?, name: String, url: String) async throws {
        guard let git else {
            throw PassError.parseFailed(String(localized: "Password store is not a Git repository."))
        }
        try await git.addRemote(name: name, url: url)
        await refresh(using: git)
    }

    func setRemoteURL(using git: GitService?, name: String, url: String) async throws {
        guard let git else {
            throw PassError.parseFailed(String(localized: "Password store is not a Git repository."))
        }
        try await git.setRemoteURL(name: name, url: url)
        await refresh(using: git)
    }

    func removeRemote(using git: GitService?, name: String) async throws {
        guard let git else {
            throw PassError.parseFailed(String(localized: "Password store is not a Git repository."))
        }
        try await git.removeRemote(name: name)
        await refresh(using: git)
    }

    func setUpstream(using git: GitService?, remoteBranch: String) async throws {
        guard let git else {
            throw PassError.parseFailed(String(localized: "Password store is not a Git repository."))
        }
        try await git.setUpstream(remoteBranch)
        await refresh(using: git)
    }

    func unsetUpstream(using git: GitService?) async throws {
        guard let git else {
            throw PassError.parseFailed(String(localized: "Password store is not a Git repository."))
        }
        try await git.unsetUpstream()
        await refresh(using: git)
    }

    func fetch(using git: GitService?, remote: String? = nil) async {
        guard let git else { return }
        isSyncing = true
        lastError = nil
        lastMessage = nil
        defer { isSyncing = false }
        do {
            try await git.fetch(remote: remote)
            lastSynced = Date()
            lastMessage = String(localized: "Fetch completed.")
            await refresh(using: git)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearMessage() {
        lastMessage = nil
        lastError = nil
    }

    /// Preferred remote for first upstream push: `origin` if present, otherwise the first remote.
    var preferredUpstreamRemoteName: String? {
        if remotes.contains(where: { $0.name == "origin" }) {
            return "origin"
        }
        return remotes.first?.name
    }
}
