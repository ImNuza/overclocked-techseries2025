import SwiftUI

struct CurrentOrderView: View {
    @Binding var orderItems: [OrderItem]
    
    private var totalAmount: Decimal {
        orderItems.reduce(0) { $0 + $1.subtotal }
    }

    var body: some View {
        VStack {
            if orderItems.isEmpty {
                Spacer()
                Text("Select products to start a new bill.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach($orderItems) { $item in
                        OrderItemRow(item: $item)
                    }
                    .onDelete(perform: deleteItem)
                }
                .listStyle(.plain)
            }
            
            HStack {
                Text("Total")
                    .font(.title2.weight(.bold))
                Spacer()
                MoneyText(amount: totalAmount, currency: .usd)
                     .font(.title2.weight(.bold))
            }
            .padding()
        }
        .frame(height: 250)
    }
    
    private func deleteItem(at offsets: IndexSet) {
        orderItems.remove(atOffsets: offsets)
    }
}

struct OrderItemRow: View {
    @Binding var item: OrderItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.product.name)
                MoneyText(amount: item.product.price, currency: .usd)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Button(action: { if item.quantity > 1 { item.quantity -= 1 } }) {
                    Image(systemName: "minus.circle")
                }
                Text("\(item.quantity)")
                    .frame(minWidth: 25)
                Button(action: { item.quantity += 1 }) {
                    Image(systemName: "plus.circle")
                }
            }
            .buttonStyle(.plain)
            
            MoneyText(amount: item.subtotal, currency: .usd)
                .frame(width: 80, alignment: .trailing)
        }
    }
}
