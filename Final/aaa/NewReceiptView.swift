import SwiftUI

struct NewReceiptView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss

    @State private var merchant: String = ""
    @State private var date: Date = Date()
    @State private var category: Category = .other
    @State private var payment: PaymentMethod = .other
    @State private var currency: Currency = .usd

    @State private var subtotalString: String = ""
    @State private var gstString: String = ""
    @State private var totalString: String = ""

    @FocusState private var focusedField: AmountField?
    private enum AmountField {
        case subtotal, gst, total
    }
    
    private var isSaveDisabled: Bool {
        merchant.isEmpty || (Decimal(string: totalString) ?? 0) <= 0
    }
    
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
                        
                        Spacer()
                    }

                    TextField("Subtotal", text: $subtotalString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .subtotal)

                    TextField("GST (9%)", text: $gstString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .gst)

                    TextField("Total", text: $totalString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .total)

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
                        saveReceipt()
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .onChange(of: subtotalString) {
                guard focusedField == .subtotal else { return }
                updateAmounts(from: .subtotal)
            }
            .onChange(of: gstString) {
                guard focusedField == .gst else { return }
                updateAmounts(from: .gst)
            }
            .onChange(of: totalString) {
                guard focusedField == .total else { return }
                updateAmounts(from: .total)
            }
        }
    }
    
    private func updateAmounts(from source: AmountField) {
        let taxRate: Decimal = 0.09

        switch source {
        case .subtotal:
            guard let subtotal = Decimal(string: subtotalString) else {
                clearAmounts(keep: .subtotal)
                return
            }
            let tax = subtotal * taxRate
            let total = subtotal + tax
            gstString = formattedString(for: tax)
            totalString = formattedString(for: total)
        case .gst:
            guard let tax = Decimal(string: gstString) else {
                clearAmounts(keep: .gst)
                return
            }
            let subtotal = tax / taxRate
            let total = subtotal + tax
            subtotalString = formattedString(for: subtotal)
            totalString = formattedString(for: total)
        case .total:
            guard let total = Decimal(string: totalString) else {
                clearAmounts(keep: .total)
                return
            }
            let subtotal = total / (1 + taxRate)
            let tax = total - subtotal
            subtotalString = formattedString(for: subtotal)
            gstString = formattedString(for: tax)
        }
    }

    private func clearAmounts(keep: AmountField?) {
        if keep != .subtotal { subtotalString = "" }
        if keep != .gst { gstString = "" }
        if keep != .total { totalString = "" }
    }
    
    private func formattedString(for decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        return formatter.string(from: decimal as NSDecimalNumber) ?? ""
    }

    private func saveReceipt() {
        guard let amount = Decimal(string: totalString) else { return }
        let newReceipt = Receipt(
            merchant: merchant,
            amount: amount,
            date: date,
            category: category,
            payment: payment,
            currency: currency
        )
        store.add(newReceipt)
    }
}
