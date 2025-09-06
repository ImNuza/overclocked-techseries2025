import SwiftUI

struct ProductCatalogView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var showingAddProductSheet = false
    
    var body: some View {
        List {
            ForEach(store.products) { product in
                HStack {
                    VStack(alignment: .leading) {
                        Text(product.name)
                            .font(.headline)
                        Text(product.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    MoneyText(amount: product.price, currency: store.merchantProfile?.defaultCurrency ?? .usd)
                }
            }
            .onDelete(perform: store.deleteProduct)
        }
        .navigationTitle("Product Catalog")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddProductSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProductSheet) {
            ProductFormView()
        }
    }
}

#Preview {
    NavigationStack {
        ProductCatalogView()
            .environmentObject(ReceiptStore())
    }
}
