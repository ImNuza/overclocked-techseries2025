import Foundation
import SwiftUI
import UIKit
import FirebaseFirestore

// MARK: App State
enum AppMode {
    case consumer
    case merchant
}

// MARK: - Models
enum Category: String, CaseIterable, Codable, Identifiable {
    case snacks = "Snacks", groceries = "Groceries", cafe = "Cafe", transport = "Transport", other = "Other"
    var id: String { rawValue }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case cash = "Cash", card = "Card", qr = "QR", applePay = "Apple Pay", other = "Other"
    var id: String { rawValue }
}

enum Currency: String, CaseIterable, Codable, Identifiable {
    case usd = "USD", sgd = "SGD", jpy = "JPY", cny = "CNY", krw = "KRW"
    var id: String { rawValue }
}

enum GreenTag: String, CaseIterable, Codable, Identifiable {
    case byoFriendly = "BYO Friendly"
    case zeroWaste = "Zero Waste Store"
    case usesSustainablePackaging = "Sustainable Packaging"
    case supportsLocalProduce = "Supports Local Produce"
    case plantBasedOptions = "Plant-Based Options"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .byoFriendly: "cup.and.saucer.fill"
        case .zeroWaste: "arrow.3.trianglepath"
        case .usesSustainablePackaging: "shippingbox.fill"
        case .supportsLocalProduce: "leaf.fill"
        case .plantBasedOptions: "carrot.fill"
        }
    }
}


struct ReceiptItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var qty: Int
    var price: Decimal
}

struct Receipt: Identifiable, Codable, Hashable {
    @DocumentID var id: String? = UUID().uuidString
    var merchant: String
    var location: String?
    var amount: Decimal
    var date: Date
    var category: Category
    var payment: PaymentMethod
    var tags: [String] = []
    var items: [ReceiptItem] = []
    var notes: String? = nil
    var currency: Currency = .usd

    private enum CodingKeys: String, CodingKey {
        case id, merchant, location, amount, date, category, payment, tags, items, notes, currency
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.merchant = try container.decode(String.self, forKey: .merchant)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.amount = try container.decode(Decimal.self, forKey: .amount)
        self.date = try container.decode(Date.self, forKey: .date)
        self.category = try container.decode(Category.self, forKey: .category)
        self.payment = try container.decode(PaymentMethod.self, forKey: .payment)
        self.items = (try container.decodeIfPresent([ReceiptItem].self, forKey: .items)) ?? []
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.currency = (try container.decodeIfPresent(Currency.self, forKey: .currency)) ?? .sgd
        self.tags = (try container.decodeIfPresent([String].self, forKey: .tags)) ?? []
    }
    
    init(id: String? = UUID().uuidString, merchant: String, location: String? = nil, amount: Decimal, date: Date, category: Category, payment: PaymentMethod, tags: [String] = [], items: [ReceiptItem] = [], notes: String? = nil, currency: Currency = .sgd) {
        self.id = id
        self.merchant = merchant
        self.location = location
        self.amount = amount
        self.date = date
        self.category = category
        self.payment = payment
        self.tags = tags
        self.items = items
        self.notes = notes
        self.currency = currency
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(merchant, forKey: .merchant)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(category, forKey: .category)
        try container.encode(payment, forKey: .payment)
        try container.encode(tags, forKey: .tags)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(currency, forKey: .currency)
    }
    
    var stableId: String {
        id ?? UUID().uuidString
    }
}

// MARK: - Merchant Mode Models
struct MerchantProfile: Codable, Identifiable {
    @DocumentID var id: String? = UUID().uuidString
    var merchantName: String
    var location: String?
    var address: String?
    var logoImageData: Data?
    var defaultCurrency: Currency = .sgd
    var greenTags: [GreenTag] = []
    
    var logoImage: UIImage? {
        guard let data = logoImageData else { return nil }
        return UIImage(data: data)
    }
}

struct ProductItem: Codable, Identifiable, Hashable {
    @DocumentID var id: String? = UUID().uuidString
    var name: String
    var price: Decimal
    var category: Category
}

// MARK: - Bill Generator Models
struct OrderItem: Identifiable, Equatable {
    var id: String { product.id ?? UUID().uuidString }
    let product: ProductItem
    var quantity: Int
    
    var subtotal: Decimal {
        product.price * Decimal(quantity)
    }
}

// MARK: - Challenge Models
enum ChallengeType: String, Codable {
    case transport
    case groceries
    case byo
}

struct Challenge: Identifiable, Codable, Hashable {
    var id: String { title }
    let title: String
    let description: String
    let targetCount: Int
    let type: ChallengeType
    let iconName: String
}

struct ChallengeProgress: Identifiable, Codable {
    @DocumentID var id: String?
    var challengeId: String
    var currentCount: Int
    var isCompleted: Bool = false
    var lastUpdated: Date
}

enum ChallengeProvider {
    static let allChallenges: [Challenge] = [
        Challenge(
            title: "Green Commuter",
            description: "Take public transport 5 times to reduce your carbon footprint.",
            targetCount: 5,
            type: .transport,
            iconName: "bus.fill"
        ),
        Challenge(
            title: "Eco Shopper",
            description: "Log 3 grocery shopping trips this month.",
            targetCount: 3,
            type: .groceries,
            iconName: "cart.fill"
        ),
        Challenge(
            title: "BYO Champion",
            description: "Bring your own container/cup and log it 4 times.",
            targetCount: 4,
            type: .byo,
            iconName: "cup.and.saucer.fill"
        )
    ]
}


// MARK: - Store (load/save JSON)
@MainActor
final class ReceiptStore: ObservableObject {
    @Published var receipts: [Receipt]
    
    @Published var appMode: AppMode = .consumer
    @Published var merchantProfile: MerchantProfile?
    @Published var products: [ProductItem]
    
    @Published var challengeProgress: [ChallengeProgress] = []
    
    init() {
        self.receipts = SampleData.receipts.sorted { $0.date > $1.date }
        self.merchantProfile = SampleData.merchantProfile
        self.products = SampleData.products
        
        recalculateAllChallengeProgress()
    }
    
    func add(_ r: Receipt) {
        receipts.insert(r, at: 0)
        updateChallengeProgress(for: r)
    }
    
    func delete(_ ids: Set<String>) {
        receipts.removeAll { ids.contains($0.stableId) }
        recalculateAllChallengeProgress()
    }

    private func recalculateAllChallengeProgress() {
        var allProgress: [ChallengeProgress] = []
        let allChallenges = ChallengeProvider.allChallenges

        for challenge in allChallenges {
            var progress = ChallengeProgress(challengeId: challenge.id, currentCount: 0, lastUpdated: Date())
            
            for receipt in receipts.reversed() {
                if isReceipt(receipt, validFor: challenge) {
                    progress.currentCount += 1
                    progress.lastUpdated = receipt.date
                }
            }
            
            if progress.currentCount >= challenge.targetCount {
                progress.isCompleted = true
            }
            allProgress.append(progress)
        }
        self.challengeProgress = allProgress
    }

    private func updateChallengeProgress(for receipt: Receipt) {
        for (index, progress) in challengeProgress.enumerated() {
            let challenge = ChallengeProvider.allChallenges.first { $0.id == progress.challengeId }
            
            guard let matchedChallenge = challenge, !progress.isCompleted else { continue }
            
            if isReceipt(receipt, validFor: matchedChallenge) {
                challengeProgress[index].currentCount += 1
                challengeProgress[index].lastUpdated = Date()
                if challengeProgress[index].currentCount >= matchedChallenge.targetCount {
                    challengeProgress[index].isCompleted = true
                }
            }
        }
    }
    
    private func isReceipt(_ receipt: Receipt, validFor challenge: Challenge) -> Bool {
        switch challenge.type {
        case .transport:
            return receipt.category == .transport
        case .groceries:
            return receipt.category == .groceries
        case .byo:
            return receipt.tags.contains(where: { $0.localizedCaseInsensitiveContains("BYO") })
        }
    }

    func co2AvoidedThisMonth(kgPerReceipt: Double = 0.1) -> Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let count = receipts.filter { $0.date >= start }.count
        return Double(count) * kgPerReceipt
    }

    func waterSavedInLiters() -> Double {
        let totalReceipts = receipts.count
        return Double(totalReceipts) * 0.5
    }

    func treesSaved() -> Double {
        let totalReceipts = receipts.count
        let a4SheetsSaved = Double(totalReceipts) / 20.0
        return a4SheetsSaved / 8333.0
    }
    
    func updateAndSaveMerchantProfile(_ profile: MerchantProfile) {
        self.merchantProfile = profile
    }
    
    func addProduct(_ product: ProductItem) {
        products.append(product)
    }

    func deleteProduct(at offsets: IndexSet) {
        products.remove(atOffsets: offsets)
    }
    
    func load() async {
    }
}


// MARK: - Sample Data
enum SampleData {
    static let baseDate = Date()
    
    static let merchantProfile = MerchantProfile(
        id: "sample-merchant-profile-123",
        merchantName: "The Green Pot",
        location: "Singapore",
        address: "1 Fullerton Road, Singapore 049213",
        logoImageData: nil,
        defaultCurrency: .sgd,
        greenTags: [.byoFriendly, .plantBasedOptions, .supportsLocalProduce]
    )
    
    static let products: [ProductItem] = [
        ProductItem(id: "prod-001", name: "Avocado Toast", price: 14.50, category: .cafe),
        ProductItem(id: "prod-002", name: "Iced Latte", price: 6.50, category: .cafe),
        ProductItem(id: "prod-003", name: "Organic Salad", price: 12.00, category: .cafe),
        ProductItem(id: "prod-004", name: "Kombucha", price: 8.00, category: .cafe),
        ProductItem(id: "prod-005", name: "Acai Bowl", price: 11.50, category: .cafe)
    ]
    
    static let receipts: [Receipt] = [
        Receipt(merchant: "The Green Pot", location: "Fullerton", amount: 21.00, date: baseDate.addingTimeInterval(-60*30), category: .cafe, payment: .applePay, tags: ["BYO Discount", "Lunch"], items: [
            ReceiptItem(name: "Avocado Toast", qty: 1, price: 14.50),
            ReceiptItem(name: "Iced Latte", qty: 1, price: 6.50)
        ]),
        Receipt(merchant: "FairPrice Finest", location: "Clementi Mall", amount: 45.70, date: baseDate.addingTimeInterval(-60*60*26), category: .groceries, payment: .card, tags: ["Groceries"], items: [
            ReceiptItem(name: "Organic Milk", qty: 1, price: 6.80),
            ReceiptItem(name: "Fresh Salmon", qty: 1, price: 15.50),
            ReceiptItem(name: "Broccoli", qty: 2, price: 4.40)
        ]),
        Receipt(merchant: "Go-Jek", amount: 18.50, date: baseDate.addingTimeInterval(-60*60*52), category: .transport, payment: .card, tags: []),
        Receipt(merchant: "Toast Box", location: "Raffles City", amount: 8.20, date: baseDate.addingTimeInterval(-60*60*100), category: .cafe, payment: .qr, tags: ["Breakfast", "BYO"]),
        Receipt(merchant: "SMRT", amount: 2.18, date: baseDate.addingTimeInterval(-60*60*110), category: .transport, payment: .card, tags: ["MRT"]),
        Receipt(merchant: "Cold Storage", location: "Plaza Singapura", amount: 22.10, date: baseDate.addingTimeInterval(-60*60*150), category: .groceries, payment: .cash, tags: ["Snacks"]),
        Receipt(merchant: "SMRT", amount: 1.95, date: baseDate.addingTimeInterval(-60*60*160), category: .transport, payment: .card, tags: ["Bus"])
    ]
}

// MARK: - Utilities & Formatters
extension Decimal { var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue } }

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "SGD"
        return f
    }()
}

extension DateFormatter {
    static let timeHM: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    static let dowHM: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE HH:mm"; return f }()
}

func prettyTimestamp(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Today " + DateFormatter.timeHM.string(from: date) }
    if cal.isDateInYesterday(date) { return "Yesterday " + DateFormatter.timeHM.string(from: date) }
    return DateFormatter.dowHM.string(from: date)
}
