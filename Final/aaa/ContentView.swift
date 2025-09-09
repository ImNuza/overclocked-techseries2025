import SwiftUI
import Charts
import QuickLook
import UIKit
import AVFoundation
import PhotosUI
import Vision
import FirebaseAuth
import FirebaseCore

// MARK: - Fix for .sheet(item:)
extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

// MARK: - Bridge Helpers (Share & PDF Preview)

struct TempFile: Identifiable { let id = UUID(); let url: URL }

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct PDFQuickLook: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in _: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

extension View {
    func asPDF(width: CGFloat = 612, height: CGFloat = 792) -> URL? {
        let size = CGSize(width: width, height: height)
        let renderer = ImageRenderer(content: self.frame(width: width, height: height).padding())
        renderer.scale = 1
        #if os(iOS)
        if let uiImage = renderer.uiImage {
            let bounds = CGRect(origin: .zero, size: size)
            let pdf = UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
                ctx.beginPage(); uiImage.draw(in: bounds)
            }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("receipt-\(UUID().uuidString).pdf")
            do { try pdf.write(to: tmp); return tmp } catch { return nil }
        }
        #endif
        return nil
    }
}

// MARK: - CSV

enum CSVBuilder {
    static func makeCSV(receipts: [Receipt]) -> String {
        var lines = ["Merchant,Amount,Currency,Date,Category,Payment,Tags"]
        let fmt = ISO8601DateFormatter()
        for r in receipts {
            let amount = NumberFormatter.currency.string(from: r.amount as NSDecimalNumber)?
                .replacingOccurrences(of: ",", with: "") ?? "0"
            let tags = r.tags.joined(separator: ";")
            let line = "\(r.merchant),\(amount),\(r.currency.rawValue),\(fmt.string(from: r.date)),\(r.category.rawValue),\(r.payment.rawValue),\(tags)"
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}

enum TempWriter {
    static func write(_ text: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try text.data(using: .utf8)?.write(to: url); return url } catch { return nil }
    }
}

// MARK: - Reusable UI

struct Pill: View {
    var text: String
    var systemImage: String? = nil
    var isOn: Bool = false
    var action: ()->Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { if let s = systemImage { Image(systemName: s) }; Text(text) }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isOn ? Color("ThemeGreen").opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isOn ? Color("ThemeGreen") : .primary)
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
}

struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
    }
}

struct MoneyText: View {
    let amount: Decimal
    let currency: Currency
    var body: some View {
        switch currency {
        case .usd:
            Text("$\(amount.doubleValue, specifier: "%.2f")")
        case .sgd:
            Text("S$\(amount.doubleValue, specifier: "%.2f")")
        case .jpy:
            Text("¥\(amount.doubleValue, specifier: "%.0f")")
        case .cny:
            Text("¥\(amount.doubleValue, specifier: "%.2f")")
        case .krw:
            Text("₩\(amount.doubleValue, specifier: "%.0f")")
        }
    }
}


// MARK: - PDF Layout

struct ReceiptPDFView: View {
    let receipt: Receipt
    private var subtotal: Decimal {
        receipt.items.reduce(0) { $0 + $1.price }
    }

    private var tax: Decimal {
        (subtotal * 0.09)
    }

    private var total: Decimal {
        subtotal + tax
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(receipt.merchant).font(.title3.weight(.semibold))
            if let loc = receipt.location { Text(loc).foregroundStyle(.secondary) }
            Text(prettyTimestamp(receipt.date)).foregroundStyle(.secondary)

            if !receipt.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items").font(.headline)
                    ForEach(receipt.items) { it in
                        HStack { Text("\(it.qty)x \(it.name)"); Spacer(); MoneyText(amount: it.price, currency: receipt.currency) }
                    }
                    
                    Divider().padding(.top, 8)
                    
            VStack(spacing: 6) {
                HStack {
                    Text("Subtotal"); Spacer()
                    MoneyText(amount: subtotal, currency: receipt.currency)
                }
                HStack {
                    Text("Tax (9%)"); Spacer()
                    MoneyText(amount: tax, currency: receipt.currency)
                }
                Divider()
                HStack {
                    Text("Total").fontWeight(.semibold); Spacer()
                    MoneyText(amount: total, currency: receipt.currency)
                        .font(.body.weight(.semibold))
                }
                    }
                }
            }
            Divider()
            HStack { Text("Category: \(receipt.category.rawValue)"); Spacer(); Text("Payment: \(receipt.payment.rawValue)") }
            if !receipt.tags.isEmpty { HStack { ForEach(receipt.tags, id: \.self) { TagChip(text: $0) } } }
            if let n = receipt.notes { Text(n).padding(.top, 8) }
            
            Spacer()
            
            HStack {
                Spacer()
                if let qrImage = QRCodeGenerator.generate(from: receipt) {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                }
                Spacer()
            }
            .padding(.top)

            HStack { Spacer(); Text("Thank you!").foregroundStyle(.secondary) }
        }
        .padding(24)
    }
}

// MARK: - Root ContentView

struct ContentView: View {
    @StateObject private var store = ReceiptStore()

    var body: some View {
        AuthView()
            .environmentObject(store)
    }
}

// MARK: - Tabs

struct RootTabView: View {
    @EnvironmentObject var store: ReceiptStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            if store.appMode == .consumer {
                DiscoverView()
                    .tabItem { Label("Discover", systemImage: "sparkles") }
                
            } else {
                RevenueView()
                    .tabItem { Label("Revenue", systemImage: "chart.bar.xaxis") }
            }

            HistoryView()
                .tabItem { Label("Expense Tracker", systemImage: "clock") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .tint(Color("ThemeGreen"))
    }
}

// MARK: - History

struct HistoryView: View {
    
    @EnvironmentObject var store: ReceiptStore
    @State private var showingCalendar = false
    
    @State private var searchText: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var selectedPayment: PaymentMethod? = nil
    @State private var sortByDateDesc: Bool = true
    @State private var selection = Set<String>()
    @State private var shareURL: URL? = nil
    
    var filtered: [Receipt] {
        store.receipts.filter { r in
            let matchSearch = searchText.isEmpty || r.merchant.lowercased().contains(searchText.lowercased())
            let matchCat = (selectedCategory == nil) || r.category == selectedCategory!
            let matchPay = (selectedPayment == nil) || r.payment == selectedPayment!
            return matchSearch && matchCat && matchPay
        }
        .sorted { sortByDateDesc ? $0.date > $1.date : $0.date < $1.date }
    }
    
    var totalThisMonth: Decimal {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let sum = store.receipts
            .filter { $0.date >= start }
            .map { $0.amount.doubleValue }
            .reduce(0, +)
        return Decimal(sum)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                if store.appMode == .consumer {
                    VStack(spacing: 8) {
                        Text("This Month")
                            .font(.headline)
                        Text(NumberFormatter.currency.string(from: totalThisMonth as NSDecimalNumber) ?? "$0.00")
                            .font(.system(size: 30, weight: .bold, design: .default))
                        Text("CO₂ avoided: \(String(format: "%.1f", store.co2AvoidedThisMonth())) kg")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                        Pill(text: "Date", systemImage: "calendar", isOn: true) { }
                        Menu {
                            Button("All") { selectedCategory = nil }
                            ForEach(Category.allCases) { c in Button(c.rawValue) { selectedCategory = c } }
                        } label: {
                            Pill(text: selectedCategory?.rawValue ?? "Category", systemImage: "tag", isOn: selectedCategory != nil) {}
                        }
                        Menu {
                            Button("All") { selectedPayment = nil }
                            ForEach(PaymentMethod.allCases) { p in Button(p.rawValue) { selectedPayment = p } }
                        } label: {
                            Pill(text: selectedPayment?.rawValue ?? "Payment", systemImage: "creditcard", isOn: selectedPayment != nil) {}
                        }
                        Pill(text: "Sort Date", systemImage: "arrow.up.arrow.down") { sortByDateDesc.toggle() }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                List {
                    ForEach(filtered) { r in
                        HStack(spacing: 12) {
                            Button {
                                if selection.contains(r.stableId) { selection.remove(r.stableId) } else { selection.insert(r.stableId) }
                            } label: {
                                Image(systemName: selection.contains(r.stableId) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                            }.buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                NavigationLink(value: r) { Text(r.merchant).font(.headline) }
                                Text(prettyTimestamp(r.date)).foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            MoneyText(amount: r.amount, currency: r.currency).font(.headline)
                        }
                    }
                }
                .listStyle(.plain)

                .safeAreaInset(edge: .bottom) {
                    Group {
                        if !selection.isEmpty {
                            HStack(spacing: 16) {
                                Button {
                                    let picked = store.receipts.filter { selection.contains($0.stableId) }
                                    let csv = CSVBuilder.makeCSV(receipts: picked)
                                    shareURL = TempWriter.write(csv, filename: "receipts-share.csv")
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.headline)
                                }

                                Spacer(minLength: 0)

                                Button(role: .destructive) {
                                    store.delete(selection)
                                    selection.removeAll()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .font(.headline)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.snappy, value: selection)
                }
                }
            .navigationTitle(store.appMode == .consumer ? "Expense Tracker" : "Sales History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(selection.isEmpty ? "Select All" : "Clear Selection") {
                            let ids = Set(filtered.map { $0.stableId })
                            if ids.isSubset(of: selection) { selection.removeAll() }
                            else { selection = ids }
                        }

                        Button("Share", systemImage: "square.and.arrow.up") {
                            let picked = store.receipts.filter { selection.contains($0.stableId) }
                            let csv = CSVBuilder.makeCSV(receipts: picked)
                            shareURL = TempWriter.write(csv, filename: "receipts-share.csv")
                        }
                        .disabled(selection.isEmpty)

                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.delete(selection)
                            selection.removeAll()
                        }
                        .disabled(selection.isEmpty)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCalendar = true }) {
                        Image(systemName: "calendar")
                    }
                }
            }
                
            .sheet(isPresented: $showingCalendar) {
                SpendingCalendarView()
            }
            .navigationDestination(for: Receipt.self) { r in ReceiptDetailView(receipt: r) }
        }
        .sheet(item: $shareURL, onDismiss: { shareURL = nil }) { f in
            ShareSheet(activityItems: [f])
        }
    }
}

struct RevenueView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var selectedTimeframe: Timeframe = .week

    enum Timeframe: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: String { self.rawValue }
    }

    private func currencyFormattedString(for amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SGD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "S$0.00"
    }

    private var filteredReceipts: [Receipt] {
        let now = Date()
        let calendar = Calendar.current
        
        var startDate: Date
        switch selectedTimeframe {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        return store.receipts.filter { $0.date >= startDate }
    }

    private var totalRevenue: Decimal {
        filteredReceipts.reduce(0) { $0 + $1.amount }
    }
    
    private var totalSales: Int {
        filteredReceipts.count
    }
    
    private var averageSale: Decimal {
        totalSales == 0 ? 0 : totalRevenue / Decimal(totalSales)
    }

    private var chartData: [RevenueDataPoint] {
        let calendar = Calendar.current
        
        switch selectedTimeframe {
        case .week:
            let dailyData = Dictionary(grouping: filteredReceipts) { receipt in
                calendar.startOfDay(for: receipt.date)
            }.mapValues { receipts in
                receipts.reduce(0) { $0 + $1.amount }
            }
            
            var dataPoints: [RevenueDataPoint] = []
            for i in 0..<7 {
                let date = calendar.date(byAdding: .day, value: -i, to: Date())!
                let startOfDay = calendar.startOfDay(for: date)
                dataPoints.append(RevenueDataPoint(dimension: .date(startOfDay), value: dailyData[startOfDay] ?? 0))
            }
            return dataPoints.sorted()

        case .month:
            let weeklyData = Dictionary(grouping: filteredReceipts) { receipt in
                calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: receipt.date))!
            }.mapValues { receipts in
                receipts.reduce(0) { $0 + $1.amount }
            }
            return weeklyData.map { RevenueDataPoint(dimension: .date($0.key), value: $0.value) }.sorted()
            
        case .year:
            let monthlyData = Dictionary(grouping: filteredReceipts) { receipt in
                calendar.date(from: calendar.dateComponents([.year, .month], from: receipt.date))!
            }.mapValues { receipts in
                receipts.reduce(0) { $0 + $1.amount }
            }
            return monthlyData.map { RevenueDataPoint(dimension: .date($0.key), value: $0.value) }.sorted()
        }
    }
    
    private var categoryData: [CategoryRevenue] {
        let grouped = Dictionary(grouping: filteredReceipts, by: { $0.category })
        let categoryTotals = grouped.mapValues { receipts in
            receipts.reduce(0) { $0 + $1.amount }
        }
        return categoryTotals.map { CategoryRevenue(category: $0.key, revenue: $0.value) }
            .sorted { $0.revenue > $1.revenue }
    }
    
    private var topSellingItems: [TopSeller] {
        var itemCounts = [String: Int]()
        for receipt in filteredReceipts {
            for item in receipt.items {
                itemCounts[item.name, default: 0] += item.qty
            }
        }
        return itemCounts.map { TopSeller(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            MetricCard(title: "Total Revenue", value: currencyFormattedString(for: totalRevenue), icon: "chart.bar.doc.horizontal")
                            MetricCard(title: "Total Sales", value: "\(totalSales)", icon: "cart")
                        }
                        MetricCard(title: "Average Sale", value: currencyFormattedString(for: averageSale), icon: "divide.circle")
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("Revenue Trend")
                            .font(.title2.weight(.bold))
                        Chart(chartData) { dataPoint in
                            BarMark(
                                x: .value("Date", dataPoint.dimension.date, unit: chartDataUnit),
                                y: .value("Revenue", dataPoint.value.doubleValue)
                            )
                            .foregroundStyle(Color("ThemeGreen"))
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisValueLabel(format: chartXAxisFormat)
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("By Category")
                                .font(.title2.weight(.bold))
                            Chart(categoryData) { category in
                                SectorMark(
                                    angle: .value("Revenue", category.revenue.doubleValue),
                                    innerRadius: .ratio(0.6)
                                )
                                .foregroundStyle(by: .value("Category", category.category.rawValue))
                            }
                            .chartLegend(position: .bottom, alignment: .center, spacing: 8)
                            .frame(height: 200)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading) {
                            Text("Top Sellers")
                                .font(.title2.weight(.bold))
                            List {
                                ForEach(topSellingItems) { item in
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text("\(item.count)")
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .frame(height: 200)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Revenue")
        }
    }
    
    private var chartDataUnit: Calendar.Component {
        switch selectedTimeframe {
        case .week: return .day
        case .month: return .weekOfYear
        case .year: return .month
        }
    }
    
    private var chartXAxisFormat: Date.FormatStyle {
        switch selectedTimeframe {
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.week(.defaultDigits)
        case .year: return .dateTime.month(.narrow)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.largeTitle.weight(.bold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RevenueDataPoint: Identifiable, Comparable {
    var id = UUID()
    let dimension: Dimension
    let value: Decimal
    
    enum Dimension: Comparable {
        case date(Date)
        var date: Date {
            switch self {
            case .date(let d): return d
            }
        }
    }
    
    static func < (lhs: RevenueDataPoint, rhs: RevenueDataPoint) -> Bool {
        lhs.dimension < rhs.dimension
    }
}

struct CategoryRevenue: Identifiable {
    var id: String { category.rawValue }
    let category: Category
    let revenue: Decimal
}

struct TopSeller: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

struct QRScannerSheet: UIViewControllerRepresentable {
    var onResult: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onResult = onResult
        vc.onCancel = onCancel
        return vc
    }
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

final class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onResult: ((String)->Void)?
    var onCancel: (() -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer!
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        let close = UIButton(type: .close)
        close.tintColor = .white
        close.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        close.layer.cornerRadius = 18
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(close)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            close.widthAnchor.constraint(equalToConstant: 36),
            close.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !session.isRunning { session.startRunning() }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let val = obj.stringValue else { return }
        session.stopRunning()
        onResult?(val)
    }
    @objc private func closeTapped() { onCancel?() }
}

func detectBarcodeStrings(in image: UIImage, completion: @escaping ([String]) -> Void) {
    guard let cg = image.cgImage else { completion([]); return }
    let req = VNDetectBarcodesRequest { request, _ in
        let strings = (request.results as? [VNBarcodeObservation])?
            .compactMap { $0.payloadStringValue } ?? []
        DispatchQueue.main.async { completion(strings) }
    }
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        do { try handler.perform([req]) } catch { DispatchQueue.main.async { completion([]) } }
    }
}

struct ProfileView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var showingProfileSetup = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if store.appMode == .merchant {
                    if let profile = store.merchantProfile {
                        MerchantProfileHeader(profile: profile)
                        List {
                            NavigationLink(destination: ProductCatalogView()) {
                                Label("Manage Product Catalog", systemImage: "list.bullet.rectangle.portrait")
                            }
                            Button("Edit Profile") { showingProfileSetup = true }
                        }
                        .listStyle(.plain)
                    } else {
                        Text("No merchant profile set up yet.")
                            .foregroundColor(.secondary)
                        Button("Set Up Merchant Profile") {
                            showingProfileSetup = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ConsumerProfileHeader()
                }
                
                Spacer().frame(height: 30)
                
                Button(action: {
                    try? Auth.auth().signOut()
                }) {
                    Text("Log Out")
                }
                .tint(.red)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Profile")
            .sheet(isPresented: $showingProfileSetup) {
                MerchantProfileSetupView(profile: store.merchantProfile)
            }
        }
    }
}

struct MerchantProfileHeader: View {
    let profile: MerchantProfile
    
    var body: some View {
        VStack {
            if let logo = profile.logoImage {
                Image(uiImage: logo)
                    .resizable().scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
            } else {
                Image(systemName: "storefront.circle.fill")
                    .font(.system(size: 120)).foregroundColor(.gray)
            }
            
            Text(profile.merchantName).font(.title.weight(.bold))
            
            if let location = profile.location {
                Text(location).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

struct ConsumerProfileHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 88)).foregroundColor(.gray)
            Text("Your Profile").font(.title2.weight(.semibold))
            Text("Paperless by default. Thanks!")
                .foregroundStyle(.secondary)
        }
    }
}


struct SpendingCalendarView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var selectedDate: Date = Date()
    private var cal: Calendar { Calendar.current }
    private var receiptsForSelectedDay: [Receipt] {
        store.receipts
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }
    private var totalsByCurrency: [(currency: Currency, amount: Decimal)] {
        let grouped = Dictionary(grouping: receiptsForSelectedDay, by: { $0.currency })
        return grouped.map { (cur, rs) in
            let sum = rs.map { $0.amount.doubleValue }.reduce(0, +)
            return (cur, Decimal(sum))
        }
        .sorted { $0.currency.rawValue < $1.currency.rawValue }
    }
    private var dayString: String {
        return selectedDate.pretty
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DatePicker("Select a date",
                           selection: $selectedDate,
                           displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total on \(dayString)")
                        .font(.headline)
                        .padding(.horizontal)
                    if totalsByCurrency.isEmpty {
                        Group {
                                    if store.appMode == .merchant {
                                        Text("No revenue recorded.")
                                    } else {
                                        Text("No spending recorded.")
                                    }
                                }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    } else {
                        ForEach(totalsByCurrency, id: \.currency) { item in
                            HStack(spacing: 8) {
                                Text(item.currency.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                MoneyText(amount: item.amount, currency: item.currency)
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(Color("ThemeGreen"))
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                List {
                    ForEach(receiptsForSelectedDay) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.merchant).font(.headline)
                                Text(DateFormatter.timeHM.string(from: r.date))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            MoneyText(amount: r.amount, currency: r.currency)
                                .font(.headline)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Calendar")
        }
    }
}

func prettyTimestamp(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Today " + DateFormatter.timeHM.string(from: date) }
    if cal.isDateInYesterday(date) { return "Yesterday " + DateFormatter.timeHM.string(from: date) }
    return DateFormatter.dateWithTime.string(from: date)
}

#Preview {
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
    return ContentView()
}
