import Foundation
import Observation

@Observable
@MainActor
final class GitSyncState {
    private(set) var status: GitStatus?
    private(set) var isSyncing = false
    private(set) var lastSynced: Date?
    private(set) var lastError: String?
    private(set) var lastMessage: String?

    func refresh(using git: GitService?) async {
        guard let git else {
            status = nil
            return
        }
        status = try? await git.status()
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
            status = try await git.status()
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
            status = try await git.status()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearMessage() {
        lastMessage = nil
        lastError = nil
    }
}
