import SwiftUI

struct ProductSelectionView: View {
    @EnvironmentObject var store: ReceiptStore
    var onSelectProduct: (ProductItem) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 100))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(store.products) { product in
                    Button(action: { onSelectProduct(product) }) {
                        VStack(spacing: 6) {
                                        Text(product.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                            MoneyText(amount: product.price, currency: store.merchantProfile?.defaultCurrency ?? .usd)
                                .font(.subheadline.weight(.semibold))
                        }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 70)
                                    .background(Color(red: 0.0, green: 0.7, blue: 0.0))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
        }
    }
}
