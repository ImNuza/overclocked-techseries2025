import UIKit
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    static func generate(from receipt: Receipt) -> UIImage? {
        let payload = QRCodePayload(
            id: receipt.id,
            merchant: receipt.merchant,
            location: receipt.location,
            amount: receipt.amount,
            date: receipt.date,
            category: receipt.category,
            payment: receipt.payment,
            tags: receipt.tags,
            items: receipt.items,
            notes: receipt.notes,
            currency: receipt.currency
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(payload) else {
            return nil
        }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = jsonData
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
