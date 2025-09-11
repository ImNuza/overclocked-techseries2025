import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var showingAddReceipt = false
    @State private var showingPDF: TempFile? = nil
    @State private var shareURL: URL? = nil
    @State private var showDetail = false // <-- Added this state variable to handle the View action
    
    var body: some View {
        if store.appMode == .merchant {
            BillGeneratorView()
        } else {
            consumerHomeView
        }
    }
    
    @ViewBuilder
    private var consumerHomeView: some View {
        let last: Receipt? = store.receipts.first
        let others: [Receipt] = Array(store.receipts.dropFirst().prefix(3))
            
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("OURECEIPT")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(Color("ThemeGreen"))
                        .padding(.horizontal)
                        .padding(.top)

                    if let last {
                        LastReceiptCard(
                            receipt: last,
                            onView: { showDetail = true }, // <-- Fixed: Added the onView closure
                            onPDF: { url in showingPDF = TempFile(url: url) },
                            onShare: { // <-- Fixed: Added the onShare closure
                                let s = "\(last.merchant) — \(NumberFormatter.currency.string(from: last.amount as NSDecimalNumber) ?? "")\n\(prettyTimestamp(last.date))"
                                shareURL = TempWriter.write(s, filename: "share.txt")
                            }
                        )
                        .sheet(isPresented: $showDetail) {
                            NavigationStack { ReceiptDetailView(receipt: last) }
                        }
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No Receipts Yet")
                                .font(.title2.weight(.bold))
                            Text("Tap the '+' button to add your first digital receipt.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Eco Impact")
                            .font(.title2.weight(.bold))
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            ImpactCard(icon: "drop.fill", value: String(format: "%.1f L", store.waterSavedInLiters()), label: "Water Saved", color: .blue)
                            ImpactCard(icon: "leaf.fill", value: String(format: "%.3f", store.treesSaved()), label: "Trees Saved", color: .green)
                        }
                        .padding(.horizontal)
                    }
                    
                    if !others.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Receipts")
                                .font(.title2.weight(.bold))
                                .padding(.horizontal)
                            
                            ForEach(others) { r in
                                NavigationLink(value: r) {
                                    SmallReceiptCard(receipt: r)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showingAddReceipt = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color("ThemeGreen"))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(for: Receipt.self) { r in ReceiptDetailView(receipt: r) }
            .sheet(item: $showingPDF) { tmp in PDFQuickLook(url: tmp.url) }
            .sheet(isPresented: $showingAddReceipt) { AddReceiptSelectionView() }
            .sheet(item: $shareURL, onDismiss: { shareURL = nil }) { f in ShareSheet(activityItems: [f]) }
        }
    }
}

struct LastReceiptCard: View {
    let receipt: Receipt
    var onView: ()->Void
    var onPDF: (URL)->Void
    var onShare: ()->Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(receipt.merchant)
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(prettyTimestamp(receipt.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MoneyText(amount: receipt.amount, currency: receipt.currency)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                Button(action: onView) {
                    Label("View", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("ThemeGreen"))

                Button(action: {
                    let v = ReceiptPDFView(receipt: receipt)
                    if let url = v.asPDF() { onPDF(url) }
                }) {
                    Label("PDF", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

// SmallReceiptCard from the first code, but with a slight shadow added for better visual consistency.
struct SmallReceiptCard: View {
    let receipt: Receipt
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(receipt.merchant)
                    .font(.system(.headline, design: .rounded).weight(.medium))
                    .foregroundColor(.primary)
                Text(prettyTimestamp(receipt.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: receipt.amount, currency: receipt.currency)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.125), radius: 10, x: 0, y: 5)
        )
    }
}


struct ImpactCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(value)
                    .font(.title3.weight(.bold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
}
