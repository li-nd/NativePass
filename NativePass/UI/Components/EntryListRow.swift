import SwiftUI

struct EntryListRow: View {
    let entry: String
    let username: String?
    let hasURL: Bool
    let hasOTP: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hasURL ? "globe" : "key")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(PassFolderNode.entryDisplayName(entry))
                    .font(.body)

                if let username, !username.isEmpty {
                    Text(username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if entry.contains("/") {
                    Text(entry)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if hasOTP {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
