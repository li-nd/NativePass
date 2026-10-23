import SwiftUI

struct OTPSetupQRSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let setupURL: String
    let entryName: String

    private static let sheetWidth: CGFloat = 400

    private var qrImage: NSImage? {
        QRCodeImageGenerator.image(from: setupURL, dimension: 280)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text(String(localized: "Setup QR Code"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Text(PassFolderNode.entryDisplayName(entryName))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)

                if let qrImage {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ContentUnavailableView(
                        String(localized: "Couldn’t Generate QR"),
                        systemImage: "qrcode",
                        description: Text(String(localized: "The setup URL could not be encoded."))
                    )
                    .frame(height: 240)
                }

                Text(String(localized: "Scan with your authenticator app to add this account."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Button("Copy Setup URL") {
                    appState.clipboard.copy(setupURL)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            HStack {
                Spacer(minLength: 0)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: Self.sheetWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}
