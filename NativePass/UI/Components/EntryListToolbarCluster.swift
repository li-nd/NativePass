import SwiftUI

struct EntryListToolbarCluster: View {
    @Binding var sortOrder: EntrySortOrder
    let onNewEntry: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(EntrySortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .help("Sort")

            Divider()
                .frame(height: 16)

            Button(action: onNewEntry) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("New Entry (⌘N)")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.quaternary.opacity(0.55), in: Capsule())
    }
}
