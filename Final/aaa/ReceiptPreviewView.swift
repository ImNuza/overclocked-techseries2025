import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiptPreviewView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss
    
    let orderItems: [OrderItem]
    let totalAmount: Decimal
    var onSave: (Receipt) -> Void
    
    @State private var selectedPayment: PaymentMethod = .other
    
    @State private var shareURL: URL? = nil

    private var determinedCategory: Category {
        guard !orderItems.isEmpty else { return .other }
        
        let categories = orderItems.map { $0.product.category }
        let categoryCounts = Dictionary(grouping: categories, by: { $0 }).mapValues { $0.count }
        
        if let mostFrequent = categoryCounts.max(by: { $0.value < $1.value }) {
            return mostFrequent.key
        } else {
            return .other
        }
    }

    private var finalReceipt: Receipt {
        let receiptItems = orderItems.map {
            ReceiptItem(name: $0.product.name, qty: $0.quantity, price: $0.subtotal)
        }
        
        let subtotal = totalAmount
        let tax = subtotal * 0.09
        let finalTotal = subtotal + tax
        
        return Receipt(
            merchant: store.merchantProfile?.merchantName ?? "My Store",
            location: store.merchantProfile?.location,
            amount: finalTotal,
            date: Date(),
            category: determinedCategory,
            payment: selectedPayment,
            items: receiptItems,
            currency: store.merchantProfile?.defaultCurrency ?? .sgd
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section(header: Text("Details")) {
                        Picker("Payment Method", selection: $selectedPayment) {
                            ForEach(PaymentMethod.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
                .frame(height: 100)
                
                ReceiptPDFView(receipt: finalReceipt)

                Spacer()
            }
            .padding(.top)
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
