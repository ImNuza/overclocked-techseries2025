import SwiftUI
import FirebaseAuth
import CoreImage.CIFilterBuiltins

struct MyQRCodeView: View {
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Show this QR to the merchant")
                .font(.title2.weight(.semibold))
            
            if let userId = userId, let qrImage = generateQRCode(from: userId) {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 5)
            } else {
                Text("Could not generate QR code.\nPlease make sure you are logged in.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)
            }
            
            Text("Your unique ID is embedded in this code.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)

        if let outputImage = filter.outputImage?.transformed(by: transform) {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}

#Preview {
    MyQRCodeView()
}
