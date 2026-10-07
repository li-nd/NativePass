import SwiftUI

/// Progressive disclosure of dirty working-tree paths (Diagnostics / Settings Sync).
struct GitChangedFilesList: View {
    let files: [GitChangedFile]
    /// Soft cap before “and N more…” — keeps long dirty trees readable.
    var visibleLimit: Int = 20

    @State private var isExpanded = true

    private var visibleFiles: [GitChangedFile] {
        Array(files.prefix(visibleLimit))
    }

    private var hiddenCount: Int {
        max(0, files.count - visibleLimit)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(visibleFiles) { file in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(file.kind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Text(file.path)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if hiddenCount > 0 {
                    Text("…and \(hiddenCount) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        } label: {
            Text("Changed files (\(files.count))")
                .foregroundStyle(.secondary)
        }
    }
}
