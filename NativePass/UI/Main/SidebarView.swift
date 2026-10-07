import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    let folders: [PassFolderNode]
    let showVerificationCodes: Bool
    @Binding var selectedCategory: SidebarSelection
    @Binding var columnVisibility: NavigationSplitViewVisibility

    var onReencryptFolder: (String) -> Void
    var onGetInfoFolder: (String) -> Void
    var onDeleteFolder: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCategory) {
                Label("All", systemImage: "tray.full")
                    .tag(SidebarSelection.all)

                if !folders.isEmpty {
                    Section {
                        ForEach(folders) { folder in
                            FolderRow(
                                node: folder,
                                selectedCategory: $selectedCategory,
                                onReencryptFolder: onReencryptFolder,
                                onGetInfoFolder: onGetInfoFolder,
                                onDeleteFolder: onDeleteFolder
                            )
                        }
                    }
                }

                if showVerificationCodes {
                    Section {
                        Label("Verification Codes", systemImage: "clock.badge.checkmark")
                            .tag(SidebarSelection.verificationCodes)
                    }
                }
            }
            .listStyle(.sidebar)
            .contentMargins(.top, 0, for: .scrollContent)

            if appState.environment.isGitRepository {
                Divider()
                GitSyncToolbarItem(style: .sidebarFooter, popoverArrowEdge: .top)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .navigationTitle("")
        .toolbar(removing: .title)
    }
}

private struct FolderRow: View {
    let node: PassFolderNode
    @Binding var selectedCategory: SidebarSelection
    var onReencryptFolder: (String) -> Void
    var onGetInfoFolder: (String) -> Void
    var onDeleteFolder: (String) -> Void

    var body: some View {
        if node.isExpandable {
            DisclosureGroup {
                ForEach(node.subfolders) { child in
                    FolderRow(
                        node: child,
                        selectedCategory: $selectedCategory,
                        onReencryptFolder: onReencryptFolder,
                        onGetInfoFolder: onGetInfoFolder,
                        onDeleteFolder: onDeleteFolder
                    )
                }
            } label: {
                folderLabel(node)
            }
        } else {
            folderLabel(node)
        }
    }

    private func folderLabel(_ node: PassFolderNode) -> some View {
        Label(
            node.name,
            systemImage: node.isExpandable ? "folder.fill" : "folder"
        )
        .tag(SidebarSelection.folder(node.id))
        .contextMenu {
            Button("Re-encrypt…") {
                onReencryptFolder(node.id)
            }
            Button("Get Info…") {
                onGetInfoFolder(node.id)
            }
            Divider()
            Button("Delete…", role: .destructive) {
                onDeleteFolder(node.id)
            }
        }
    }
}
