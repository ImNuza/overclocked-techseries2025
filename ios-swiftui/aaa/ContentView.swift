import SwiftUI
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
        (subtotal * 0.09)  // 9% tax, rounded to 2 decimals
    }

    private var total: Decimal {
        subtotal + tax
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
//            HStack{
//                Text("RECEIPT")
//                    .font(.largeTitle.weight(.bold))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.6)   // scales down on small widths
//                    .allowsTightening(true)    // tighter kerning instead of wrapping
//                    .layoutPriority(1)         // claim width in the HStack
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//            HStack { Text("RECEIPT").font(.largeTitle.weight(.bold)); Spacer(); /*oneyText(amount: receipt.amount, currency: receipt.currency).font(.title2.weight(.semibold))*/ }
            
//            HStack {
//                Text("RECEIPT")
//
//                    .font(.largeTitle.weight(.bold))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.5)
//                    .allowsTightening(true)
//                    .frame(maxWidth: .infinity, alignment: .bottom)

                // remove Spacer() here if you already have a title/actions toolbar
//            }
            
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
                        .frame(width: 100, height: 100)
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
//                ChallengeView()
//                    .tabItem { Label("Challenges", systemImage: "target") }
//
                ExpensesView()
                    .tabItem { Label("Expenses", systemImage: "leaf.fill") }
                
                DiscoverView()
                    .tabItem { Label("Discover", systemImage: "sparkles") }
                
            } else {
                RevenueView()
                    .tabItem { Label("Revenue", systemImage: "chart.bar.xaxis") }
            }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

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
    private var totalSales: Decimal {
        filtered.reduce(.zero) { $0 + $1.amount }
    }
    var filtered: [Receipt] {
        store.receipts.filter { r in
            let matchSearch = searchText.isEmpty || r.merchant.lowercased().contains(searchText.lowercased())
            let matchCat = (selectedCategory == nil) || r.category == selectedCategory!
            let matchPay = (selectedPayment == nil) || r.payment == selectedPayment!
            return matchSearch && matchCat && matchPay
        }
        .sorted { sortByDateDesc ? $0.date > $1.date : $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                HStack {
                    Text("Total Sales").font(.system(size: 30, weight: .bold, design: .default))
                    Spacer()
                    Text(NumberFormatter.currency.string(from: totalSales as NSDecimalNumber) ?? "S$0.00")
                        .font(.system(size: 30, weight: .bold, design: .default))
                }
                .frame(height: 50)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.green.opacity(0.5))
                )
                .padding(.horizontal, 10)
                .padding(.top, 4)
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

                HStack {
                    Button {
                        let ids = Set(filtered.map { $0.stableId })
                        if ids.isSubset(of: selection) { selection.removeAll() }
                        else { selection = ids }
                    } label: { Label("Select", systemImage: "checkmark.circle") }
                    Spacer()
                    Button {
                        let picked = store.receipts.filter { selection.contains($0.stableId) }
                        let csv = CSVBuilder.makeCSV(receipts: picked)
                        shareURL = TempWriter.write(csv, filename: "receipts-share.csv")
                    } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .disabled(selection.isEmpty)
                    Spacer()
                    Button {
                        store.delete(selection)
                        selection.removeAll()
                    } label: { Label("Delete", systemImage: "trash") }
                    .tint(.red)
                    .disabled(selection.isEmpty)
                    Spacer()
                    Button {
                        let picked = store.receipts.filter { selection.contains($0.stableId) }
                        let csv = CSVBuilder.makeCSV(receipts: picked)
                        shareURL = TempWriter.write(csv, filename: "receipts-export.csv")
                    } label: { Label("Export", systemImage: "square.and.arrow.up.on.square") }
                    .disabled(selection.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(store.appMode == .consumer ? "History" : "Sales History")
            .toolbar {
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

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var tempPDF: URL? = nil
    @State private var shareURL: URL? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text(receipt.merchant).font(.title2.weight(.bold)); Spacer(); MoneyText(amount: receipt.amount, currency: receipt.currency).font(.title2.weight(.semibold)) }
                Text(prettyTimestamp(receipt.date)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label(receipt.category.rawValue, systemImage: "tag")
                    Label(receipt.payment.rawValue, systemImage: "creditcard")
                }.font(.subheadline)
                if !receipt.tags.isEmpty { HStack { ForEach(receipt.tags, id: \.self) { TagChip(text: $0) } } }
                if !receipt.items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items").font(.headline)
                        ForEach(receipt.items) { it in
                            HStack { Text("\(it.qty) × \(it.name)"); Spacer(); MoneyText(amount: it.price, currency: receipt.currency) }
                        }
                    }
                }
                if let n = receipt.notes { Text(n) }
                HStack(spacing: 10) {
                    Pill(text: "PDF") {
                        let v = ReceiptPDFView(receipt: receipt)
                        if let url = v.asPDF() { tempPDF = url }
                    }
                    Pill(text: "Share") {
                        let s = "\(receipt.merchant) – \(prettyTimestamp(receipt.date))\nAmount: \(NumberFormatter.currency.string(from: receipt.amount as NSDecimalNumber) ?? "")"
                        shareURL = TempWriter.write(s, filename: "receipt.txt")
                    }
                }
                Section(header: Text("QR Code").font(.headline).padding(.top)) {
                    if let qrImage = QRCodeGenerator.generate(from: receipt) {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.largeTitle)
                            Text("Could not generate QR Code")
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Receipt")
        .sheet(item: Binding(get: { tempPDF.map { TempFile(url: $0) } }, set: { _ in tempPDF = nil })) { f in
            PDFQuickLook(url: f.url)
        }
        .sheet(item: $shareURL, onDismiss: { shareURL = nil }) { f in
            ShareSheet(activityItems: [f])
        }
    }
}

struct GreenTarget: Identifiable {
    let id = UUID()
    let year: Int
    let description: String
    let progress: Double
}

let greenPlanTargets: [GreenTarget] = [
    GreenTarget(year: 2026,
                description: "Develop 130 ha new parks, enhance 170 ha existing parks",
                progress: 0.4),
    GreenTarget(year: 2030,
                description: "Plant 1M more trees, +50% nature parks, park within 10min walk",
                progress: 0.25),
    GreenTarget(year: 2035,
                description: "Add 1000 ha of green spaces",
                progress: 0.1)
]

struct ExpensesView: View {
    @EnvironmentObject var store: ReceiptStore
    
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
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("This Month")
                        .font(.headline)
                    Text(NumberFormatter.currency.string(from: totalThisMonth as NSDecimalNumber) ?? "$0.00")
                        .font(.largeTitle.weight(.bold))
                    Text("CO₂ avoided: \(String(format: "%.1f", store.co2AvoidedThisMonth())) kg")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Singapore Green Plan 2030 Targets")
                        .font(.title3.weight(.bold))

                    ForEach(greenPlanTargets) { target in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(String(target.year)) target")
                                .font(.headline)
                            Text(target.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Gauge(value: target.progress) {
                                Text("Progress")
                            } currentValueLabel: {
                                Text("\(Int(target.progress * 100))%")
                            }
                            .tint(.green)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Expenses")
    }
}

struct RevenueView: View {
    var body: some View {
        NavigationStack {
            Text("Revenue data will be shown here.")
                .navigationTitle("Revenue")
        }
    }
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
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: selectedDate)
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

let prettyDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium   // e.g., Sep 6, 2025
    f.timeStyle = .short    // e.g., 14:22
    f.doesRelativeDateFormatting = false // prevent "Today"/"Yesterday"
    return f
}()

func prettyTimestampContent(_ date: Date) -> String {
    prettyDateFormatter.string(from: date)
}

#Preview {
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
    return ContentView()
}
