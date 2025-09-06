import UIKit
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    static func generate(from receipt: Receipt) -> UIImage? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys // Ensure consistent JSON output

        do {
            let data = try encoder.encode(receipt)
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            
            filter.setValue(data, forKey: "inputMessage")

            let transform = CGAffineTransform(scaleX: 10, y: 10)

            if let outputImage = filter.outputImage?.transformed(by: transform) {
                if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
            return nil
        } catch {
            print("ERROR: Failed to encode receipt for QR code. \(error.localizedDescription)")
            return nil
        }
    }
}
