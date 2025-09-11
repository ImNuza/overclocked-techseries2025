import SwiftUI

struct BillGeneratorView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var currentOrderItems: [OrderItem] = []
    @State private var showingReceiptPreview = false
    @State private var showingProfileSetup = false

    private var totalAmount: Decimal {
        currentOrderItems.reduce(0) { $0 + $1.subtotal }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                CurrentOrderView(orderItems: $currentOrderItems)
                Divider()
                ProductSelectionView(onSelectProduct: addProductToOrder)
                Button("Generate Receipt") {
                        if !currentOrderItems.isEmpty {
                            showingReceiptPreview = true
                        }
                    }
                .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(currentOrderItems.isEmpty ? Color.gray.opacity(0.3) : Color(red: 0.0, green: 0.5, blue: 0.0))
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .bold))
                    .cornerRadius(10)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .disabled(currentOrderItems.isEmpty)
                }
            
            
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Bill")
                        .font(.system(size: 30, weight: .bold))
                        .padding(.top,10)
                        .onTapGesture(count: 5) {
                            if store.appMode == .consumer {
                                store.appMode = .merchant
                            } else {
                                store.appMode = .consumer
                            }
                                
                        }
                }
            }
            .sheet(isPresented: $showingReceiptPreview) {
                ReceiptPreviewView(
                    orderItems: currentOrderItems,
                    totalAmount: totalAmount,
                    onSave: { finalReceipt in
                        Task {
                            await store.add(finalReceipt)
                            await MainActor.run {
                                currentOrderItems = []
                                showingReceiptPreview = false
                            }
                        }
                    }
                )
            }
            .onChange(of: store.products) { _, newProducts in
                let availableProductIDs = Set(newProducts.map { $0.id })
                currentOrderItems = currentOrderItems.filter { availableProductIDs.contains($0.product.id) }
            }
        }
    }

    private func addProductToOrder(_ product: ProductItem) {
        if let index = currentOrderItems.firstIndex(where: { $0.product.id == product.id }) {
            currentOrderItems[index].quantity += 1
        } else {
            let newOrderItem = OrderItem(product: product, quantity: 1)
            currentOrderItems.append(newOrderItem)
        }
    }
}
