import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeImageGenerator {
    /// Renders a QR code for `string`. Returns nil if encoding fails.
    static func image(from string: String, dimension: CGFloat = 280) -> NSImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmed.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scale = max(dimension / output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: NSSize(width: dimension, height: dimension))
        image.addRepresentation(rep)
        return image
    }
}
