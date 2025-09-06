import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var showingPDF: TempFile? = nil
    @State private var showDetail = false
    @State private var shareURL: URL? = nil
    @State private var showingAddReceipt = false
    
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
                VStack(alignment: .leading, spacing: 16) {
                    if let last {
                        LastReceiptCard(receipt: last,
                                            onView: { showDetail = true },
                                        onPDF: { url in showingPDF = TempFile(url: url) },
                                        onShare: {
                                            let s = "\(last.merchant) — \(NumberFormatter.currency.string(from: last.amount as NSDecimalNumber) ?? "")\n\(prettyTimestamp(last.date))"
                                            shareURL = TempWriter.write(s, filename: "share.txt")
                                        })
                            .sheet(isPresented: $showDetail) { NavigationStack { ReceiptDetailView(receipt: last) } }
                    }

                    HStack(spacing: 20) {
                        Spacer()
                        VStack {
                            Image(systemName: "drop.fill")
                                .font(.title2)
                                .foregroundColor(Color("ThemeBrown"))
                            Text("\(store.waterSavedInLiters(), specifier: "%.1f") L")
                                .font(.headline)
                            Text("Water Saved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            Image(systemName: "tree.fill")
                                .font(.title2)
                                .foregroundColor(Color("ThemeGreen"))
                            Text("\(store.treesSaved(), specifier: "%.4f") Trees")
                                .font(.headline)
                            Text("Trees Saved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)


                    ForEach(others) { r in
                        NavigationLink(value: r) { SmallReceiptCard(receipt: r) }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("OURECEIPT 🌳")
                        .font(.headline)
                        .onTapGesture(count: 5) {
                            if store.appMode == .consumer {
                                store.appMode = .merchant
                            } else {
                                store.appMode = .consumer
                            }
                        }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddReceipt = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: Receipt.self) { r in ReceiptDetailView(receipt: r) }
            .sheet(item: $showingPDF) { tmp in PDFQuickLook(url: tmp.url) }
            .sheet(item: $shareURL, onDismiss: { shareURL = nil }) { f in ShareSheet(activityItems: [f]) }
            .sheet(isPresented: $showingAddReceipt) {
                AddReceiptSelectionView()
            }
        }
    }
}


struct LastReceiptCard: View {
    let receipt: Receipt
    var onView: ()->Void
    var onPDF: (URL)->Void
    var onShare: ()->Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(receipt.merchant).font(.headline)
                    MoneyText(amount: receipt.amount, currency: receipt.currency)
                        .font(.title3.weight(.bold))
                    Text(prettyTimestamp(receipt.date)).foregroundStyle(.secondary)
                    if !receipt.tags.isEmpty {
                        HStack { ForEach(receipt.tags, id: \.self) { TagChip(text: $0) } }
                    }
                }
                Spacer()
                MoneyText(amount: receipt.amount, currency: receipt.currency)
                    .font(.title3.weight(.semibold))
            }
            HStack(spacing: 10) {
                Pill(text: "View", action: onView)
                Pill(text: "PDF") {
                    let v = ReceiptPDFView(receipt: receipt)
                    if let url = v.asPDF() { onPDF(url) }
                }
                Pill(text: "Share", action: onShare)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal)
    }
}

struct SmallReceiptCard: View {
    let receipt: Receipt
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchant).font(.headline)
                Text(prettyTimestamp(receipt.date)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: receipt.amount, currency: receipt.currency)
                .font(.headline)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}
