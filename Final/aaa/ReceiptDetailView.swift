import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var tempPDF: URL? = nil
    @State private var shareURL: URL? = nil

    private var subtotal: Decimal {
        if !receipt.items.isEmpty {
            return receipt.items.reduce(0) { $0 + $1.price }
        } else {
            return receipt.amount / 1.09
        }
    }

    private var tax: Decimal {
        subtotal * 0.09
    }

    private var total: Decimal {
        receipt.amount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(receipt.merchant).font(.title2.weight(.bold))
                    Spacer()
                    MoneyText(amount: total, currency: receipt.currency).font(.title2.weight(.semibold))
                }
                Text(prettyTimestamp(receipt.date)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label(receipt.category.rawValue, systemImage: "tag")
                    Label(receipt.payment.rawValue, systemImage: "creditcard")
                }.font(.subheadline)
                if !receipt.tags.isEmpty { HStack { ForEach(receipt.tags, id: \.self) { TagChip(text: $0) } } }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if !receipt.items.isEmpty {
                        Text("Items").font(.headline)
                        ForEach(receipt.items) { it in
                            HStack { Text("\(it.qty) × \(it.name)"); Spacer(); MoneyText(amount: it.price, currency: receipt.currency) }
                        }
                        Divider().padding(.vertical, 4)
                    }

                    HStack {
                        Text("Subtotal").foregroundStyle(.secondary)
                        Spacer()
                        MoneyText(amount: subtotal, currency: receipt.currency)
                    }
                    HStack {
                        Text("GST (9%)").foregroundStyle(.secondary)
                        Spacer()
                        MoneyText(amount: tax, currency: receipt.currency)
                    }
                    HStack {
                        Text("Total").fontWeight(.bold)
                        Spacer()
                        MoneyText(amount: total, currency: receipt.currency)
                            .fontWeight(.bold)
                    }
                }

                if let n = receipt.notes {
                    Text(n).padding(.top)
                }

                HStack(spacing: 10) {
                    Pill(text: "PDF") {
                        let v = ReceiptPDFView(receipt: receipt)
                        if let url = v.asPDF() { tempPDF = url }
                    }
                    Pill(text: "Share") {
                        let s = "\(receipt.merchant) – \(prettyTimestamp(receipt.date))\nAmount: \(NumberFormatter.currency.string(from: receipt.amount as NSDecimalNumber) ?? "")"
                        shareURL = TempWriter.write(s, filename: "receipt.txt")
                    }
                }
                .padding(.top)
                
                Section(header: Text("QR Code").font(.headline).padding(.top)) {
                    if let qrImage = QRCodeGenerator.generate(from: receipt) {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.largeTitle)
                            Text("Could not generate QR Code")
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Receipt")
        .sheet(item: Binding(get: { tempPDF.map { TempFile(url: $0) } }, set: { _ in tempPDF = nil })) { f in
            PDFQuickLook(url: f.url)
        }
        .sheet(item: $shareURL, onDismiss: { shareURL = nil }) { f in
            ShareSheet(activityItems: [f])
        }
    }
}
