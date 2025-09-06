import SwiftUI

struct NewReceiptView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss

    @State private var merchant: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    @State private var category: Category = .other
    @State private var payment: PaymentMethod = .other
    @State private var currency: Currency = .usd

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Merchant", text: $merchant)
                    HStack {
                        Picker("Currency", selection: $currency) {
                            ForEach(Currency.allCases) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()

                        Spacer()

                        TextField("0.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Date", selection: $date)
                }
                Section(header: Text("Categorization")) {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    Picker("Payment Method", selection: $payment) {
                        ForEach(PaymentMethod.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }
            }
            .navigationTitle("New Receipt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = Decimal(string: amountString) else { return }
                        let newReceipt = Receipt(
                            merchant: merchant,
                            amount: amount,
                            date: date,
                            category: category,
                            payment: payment,
                            currency: currency
                        )
                        store.add(newReceipt)
                        dismiss()
                    }
                    .disabled(merchant.isEmpty || Decimal(string: amountString) == nil || (Decimal(string: amountString) ?? 0) <= 0)
                }
            }
        }
    }
}
