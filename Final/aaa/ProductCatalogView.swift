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
        .navigationTitle("Product Catalogue")
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddProductSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.green))
                            .shadow(radius: 4)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 25)
                }
            }
        )
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
