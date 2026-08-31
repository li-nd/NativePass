import SwiftUI

enum EntrySortOrder: String, CaseIterable, Identifiable {
    case byName
    case byPath

    var id: String { rawValue }

    var label: String {
        switch self {
        case .byName: return String(localized: "Name")
        case .byPath: return String(localized: "Path")
        }
    }

    func sorted(_ entries: [String]) -> [String] {
        switch self {
        case .byName:
            return entries.sorted {
                PassFolderNode.entryDisplayName($0).localizedCaseInsensitiveCompare(
                    PassFolderNode.entryDisplayName($1)
                ) == .orderedAscending
            }
        case .byPath:
            return entries.sorted()
        }
    }
}

struct EntryListView: View {
    let entries: [String]
    let folderTitle: String
    let emptyTitle: String
    let emptyDescription: String
    @Binding var selectedEntry: String?
    @Binding var searchText: String
    @Binding var sortOrder: EntrySortOrder
    let onNewEntry: () -> Void

    @Environment(AppState.self) private var appState

    private var filteredEntries: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // When searching, `entries` is already fuzzy-ranked by MainView — keep that order.
        if query.isEmpty {
            return sortOrder.sorted(entries)
        }
        return entries
    }

    private var itemCountLabel: String {
        let count = filteredEntries.count
        return count == 1
            ? String(localized: "1 Item")
            : String(localized: "\(count) Items")
    }

    private var listNavigationTitle: String {
        searchText.isEmpty ? folderTitle : String(localized: "Search")
    }

    var body: some View {
        Group {
            if filteredEntries.isEmpty && searchText.isEmpty {
                PassEmptyState(
                    title: emptyTitle,
                    systemImage: "key",
                    description: emptyDescription
                )
            } else if filteredEntries.isEmpty {
                PassEmptyState(
                    title: String(localized: "No Results"),
                    systemImage: "magnifyingglass",
                    description: String(localized: "Try a different search term.")
                )
            } else {
                List(filteredEntries, id: \.self, selection: $selectedEntry) { entry in
                    EntryListRow(
                        entry: entry,
                        username: appState.metadataCache.metadata(for: entry)?.username,
                        hasURL: appState.metadataCache.metadata(for: entry)?.url != nil,
                        hasOTP: appState.metadataCache.metadata(for: entry)?.hasOTP == true
                    )
                    .tag(entry)
                }
                .listStyle(.plain)
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
        .navigationTitle(listNavigationTitle)
        .navigationSubtitle(searchText.isEmpty ? itemCountLabel : "")
        .toolbar {
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItemGroup(placement: .primaryAction) {
                EntryListToolbarCluster(
                    sortOrder: $sortOrder,
                    onNewEntry: onNewEntry
                )
            }
        }
    }
}
