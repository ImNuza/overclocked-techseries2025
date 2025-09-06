import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiptPreviewView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss
    
    let orderItems: [OrderItem]
    let totalAmount: Decimal
    var onSave: (Receipt) -> Void
    
    @State private var selectedCategory: Category = .other
    @State private var selectedPayment: PaymentMethod = .other
    
    @State private var shareURL: URL? = nil

    private var finalReceipt: Receipt {
        let receiptItems = orderItems.map {
            ReceiptItem(name: $0.product.name, qty: $0.quantity, price: $0.subtotal)
        }
        
        return Receipt(
            merchant: store.merchantProfile?.merchantName ?? "My Store",
            location: store.merchantProfile?.location,
            amount: totalAmount,
            date: Date(),
            category: selectedCategory,
            payment: selectedPayment,
            items: receiptItems,
            currency: store.merchantProfile?.defaultCurrency ?? .sgd
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ReceiptPDFView(receipt: finalReceipt)
                
                Form {
                    Section(header: Text("Details")) {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Payment Method", selection: $selectedPayment) {
                            ForEach(PaymentMethod.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
                .frame(height: 150)
                
//                if let qrCodeImage = QRCodeGenerator.generate(from: finalReceipt) {
//                    Image(uiImage: qrCodeImage)
//                        .resizable()
//                        .interpolation(.none)
//                        .scaledToFit()
//                        .frame(width: 150, height: 150)
//                } else {
//                    VStack {
//                        Image(systemName: "xmark.circle")
//                            .font(.largeTitle)
//                        Text("Could not generate QR Code")
//                            .font(.caption)
//                    }
//                    .foregroundColor(.secondary)
//                    .frame(width: 150, height: 150)
//                }
                Spacer()
            }
            .navigationTitle("Finalize & Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            onSave(finalReceipt)
                        }) {
                            Label("Save to Sales History", systemImage: "tray.and.arrow.down")
                        }
                        Button(action: shareAsPDF) {
                            Label("Share as PDF", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Text("Actions")
                    }
                }
            }
            .sheet(item: $shareURL) { f in
                ShareSheet(activityItems: [f])
            }
        }
    }
    
    private func shareAsPDF() {
        let v = ReceiptPDFView(receipt: finalReceipt)
        if let url = v.asPDF() {
            shareURL = url
        }
    }
}
