import SwiftUI

enum GitSyncPresentationStyle {
    case compact
    case sidebarFooter
}

struct GitSyncToolbarItem: View {
    @Environment(AppState.self) private var appState
    @State private var showPopover = false

    var style: GitSyncPresentationStyle = .compact
    var popoverArrowEdge: Edge = .bottom

    var body: some View {
        if appState.environment.isGitRepository {
            Button {
                guard !appState.appLock.isBlocking else { return }
                showPopover.toggle()
            } label: {
                switch style {
                case .compact:
                    GitSyncButtonLabel(
                        badge: appState.gitSync.status?.syncBadge,
                        isSyncing: appState.gitSync.isSyncing
                    )
                case .sidebarFooter:
                    HStack(spacing: 8) {
                        GitSyncButtonLabel(
                            badge: appState.gitSync.status?.syncBadge,
                            isSyncing: appState.gitSync.isSyncing
                        )
                        Text("Sync")
                            .font(.subheadline)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .help("Git Sync")
            .disabled(appState.appLock.isBlocking)
            .popover(isPresented: $showPopover, arrowEdge: popoverArrowEdge) {
                GitSyncPopover(showPopover: $showPopover)
                    .environment(appState)
            }
            .task {
                await appState.refreshGitStatus()
            }
        }
    }
}

private struct GitSyncButtonLabel: View {
    let badge: GitSyncBadge?
    let isSyncing: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }

            if let badge, !isSyncing {
                GitSyncBadgeView(badge: badge)
                    .offset(x: 6, y: -6)
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct GitSyncBadgeView: View {
    let badge: GitSyncBadge

    var body: some View {
        switch badge {
        case .upToDate:
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        case .dirty:
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
        case .pull:
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.blue)
        case .push:
            Image(systemName: "arrow.up")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.blue)
        case .both:
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.blue)
        }
    }
}

private struct GitSyncPopover: View {
    @Environment(AppState.self) private var appState
    @Binding var showPopover: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Git Sync")
                .font(.headline)

            if let status = appState.gitSync.status {
                LabeledContent("Branch", value: status.branch ?? "—")

                if !status.isClean {
                    LabeledContent("Changes", value: String(localized: "\(status.changedFilesCount) file(s)"))
                }

                if status.hasUpstream {
                    if status.behindCount > 0 {
                        LabeledContent("Remote", value: String(localized: "\(status.behindCount) commit(s) to pull"))
                    }
                    if status.aheadCount > 0 {
                        LabeledContent("Local", value: String(localized: "\(status.aheadCount) commit(s) to push"))
                    }
                    if status.isClean && status.aheadCount == 0 && status.behindCount == 0 {
                        Label("Up to date", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                } else {
                    Text("No upstream configured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Loading status…")
                    .foregroundStyle(.secondary)
            }

            if let error = appState.gitSync.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let message = appState.gitSync.lastMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack {
                Button("Pull") {
                    guard !appState.appLock.isBlocking else { return }
                    Task {
                        await appState.gitSync.pull(using: appState.git)
                        await appState.reloadEntries()
                    }
                }
                .disabled(appState.gitSync.isSyncing || appState.appLock.isBlocking)

                Button("Push") {
                    guard !appState.appLock.isBlocking else { return }
                    Task {
                        await appState.gitSync.push(using: appState.git)
                    }
                }
                .disabled(appState.gitSync.isSyncing || appState.appLock.isBlocking)

                Button("Refresh") {
                    Task { await appState.refreshGitStatus() }
                }
                .disabled(appState.gitSync.isSyncing)
            }

            if let lastSynced = appState.gitSync.lastSynced {
                Text("Last synced \(lastSynced.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
