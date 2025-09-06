import SwiftUI

struct ProductFormView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var priceString: String = ""
    @State private var category: Category = .other

    var body: some View {
        NavigationStack {
            Form {
                Section("Product Details") {
                    TextField("Product Name", text: $name)
                    TextField("Price", text: $priceString)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
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
                        saveProduct()
                        dismiss()
                    }
                    .disabled(name.isEmpty || Decimal(string: priceString) == nil)
                }
            }
        }
    }
    
    private func saveProduct() {
        guard let price = Decimal(string: priceString) else { return }
        let newProduct = ProductItem(name: name, price: price, category: category)
        store.addProduct(newProduct)
    }
}
