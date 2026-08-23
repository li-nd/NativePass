import SwiftUI

struct CopiedFeedbackBadge: View {
    var font: Font = .caption

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.on.doc")
                .font(font)
                .symbolRenderingMode(.hierarchical)
            Text("Copied")
                .font(font)
        }
        .foregroundStyle(.secondary)
    }
}
