import SwiftUI

struct ProductFormView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var priceString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Product Details") {
                    TextField("Product Name", text: $name)
                    TextField("Price", text: $priceString)
                        .keyboardType(.decimalPad)
                    
                        }
                    }
                
            
            .navigationTitle("New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveProduct()
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || Decimal(string: priceString) == nil)
                }
            }
        }
    }
    
    private func saveProduct() async {
        guard let price = Decimal(string: priceString) else { return }
        let newProduct = ProductItem(name: name, price: price,category: .other)
        await store.addProduct(newProduct)
    }
}
