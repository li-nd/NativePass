import SwiftUI

struct EntryHeroHeader: View {
    let entryPath: String
    var emptyTitle: String = "New Entry"

    private var trimmedPath: String {
        entryPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        let name = PassFolderNode.entryDisplayName(trimmedPath)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if name.isEmpty {
            return emptyTitle
        }
        return name
    }

    private var isPlaceholder: Bool {
        PassFolderNode.entryDisplayName(trimmedPath)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .isEmpty
    }

    private var heroLetter: String {
        displayName.prefix(1).uppercased()
    }

    private var showsPathCaption: Bool {
        !isPlaceholder && trimmedPath.contains("/") && trimmedPath != displayName
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 72, height: 72)

                if !isPlaceholder, displayName.first?.isLetter == true {
                    Text(heroLetter)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "key.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }

            Text(displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if showsPathCaption {
                Text(trimmedPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
