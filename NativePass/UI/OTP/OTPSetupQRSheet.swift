import SwiftUI

struct OTPSetupQRSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let setupURL: String
    let entryName: String

    private var qrImage: NSImage? {
        QRCodeImageGenerator.image(from: setupURL, dimension: 280)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(PassFolderNode.entryDisplayName(entryName))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

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
                    .padding(.horizontal, 8)

                Button("Copy Setup URL") {
                    appState.clipboard.copy(setupURL)
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .navigationTitle(String(localized: "Setup QR Code"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 360, height: 460)
    }
}
