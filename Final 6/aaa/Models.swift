import Foundation
import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseAuth

struct QRCodePayload: Codable {
    var id: String?
    var merchant: String
    var location: String?
    var merchantAddress: String?
    var merchantPhoneNumber: String?
    var amount: Decimal
    var date: Date
    var category: Category
    var payment: PaymentMethod
    var tags: [String]
    var items: [ReceiptItem]
    var notes: String?
    var currency: Currency
}

enum AppMode {
    case consumer
    case merchant
}

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
    var merchantAddress: String?
    var merchantPhoneNumber: String?
    var amount: Decimal
    var date: Date
    var category: Category
    var payment: PaymentMethod
    var tags: [String] = []
    var items: [ReceiptItem] = []
    var notes: String? = nil
    var currency: Currency = .usd

    private enum CodingKeys: String, CodingKey {
        case id, merchant, location, merchantAddress, merchantPhoneNumber, amount, date, category, payment, tags, items, notes, currency
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.merchant = try container.decode(String.self, forKey: .merchant)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.merchantAddress = try container.decodeIfPresent(String.self, forKey: .merchantAddress)
        self.merchantPhoneNumber = try container.decodeIfPresent(String.self, forKey: .merchantPhoneNumber)
        self.amount = try container.decode(Decimal.self, forKey: .amount)
        self.date = try container.decode(Date.self, forKey: .date)
        self.category = try container.decode(Category.self, forKey: .category)
        self.payment = try container.decode(PaymentMethod.self, forKey: .payment)
        self.items = (try container.decodeIfPresent([ReceiptItem].self, forKey: .items)) ?? []
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.currency = (try container.decodeIfPresent(Currency.self, forKey: .currency)) ?? .sgd
        self.tags = (try container.decodeIfPresent([String].self, forKey: .tags)) ?? []
    }
    
    init(id: String? = UUID().uuidString, merchant: String, location: String? = nil, merchantAddress: String? = nil, merchantPhoneNumber: String? = nil, amount: Decimal, date: Date, category: Category, payment: PaymentMethod, tags: [String] = [], items: [ReceiptItem] = [], notes: String? = nil, currency: Currency = .sgd) {
        self.id = id
        self.merchant = merchant
        self.location = location
        self.merchantAddress = merchantAddress
        self.merchantPhoneNumber = merchantPhoneNumber
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
        try container.encodeIfPresent(merchantAddress, forKey: .merchantAddress)
        try container.encodeIfPresent(merchantPhoneNumber, forKey: .merchantPhoneNumber)
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

struct MerchantProfile: Codable, Identifiable {
    @DocumentID var id: String? = UUID().uuidString
    var merchantName: String
    var location: String?
    var address: String?
    var phoneNumber: String?
    var logoImageData: Data?
    var defaultCurrency: Currency = .sgd
    var greenTags: [GreenTag] = []
    var hasGreenTags: Bool = false
    
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

struct OrderItem: Identifiable, Equatable {
    var id: String { product.id ?? UUID().uuidString }
    let product: ProductItem
    var quantity: Int
    
    var subtotal: Decimal {
        product.price * Decimal(quantity)
    }
}

@MainActor
final class ReceiptStore: ObservableObject {
    @Published var receipts: [Receipt]
    
    @Published var appMode: AppMode = .consumer
    @Published var merchantProfile: MerchantProfile?
    @Published var products: [ProductItem]
    
    private let db = Firestore.firestore()

    init() {
        self.receipts = []
        self.merchantProfile = nil
        self.products = []
    }
    
    func clearAllUserData() {
        receipts.removeAll()
        merchantProfile = nil
        products.removeAll()
        appMode = .consumer
    }
    
    func add(_ r: Receipt) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var newReceipt = r
        let collectionPath: String
        
        if appMode == .merchant {
            collectionPath = "merchant_profiles/\(uid)/receipts"
        } else {
            collectionPath = "consumer_data/\(uid)/receipts"
        }
        
        do {
            let ref = try db.collection(collectionPath).addDocument(from: newReceipt)
            newReceipt.id = ref.documentID
            receipts.insert(newReceipt, at: 0)
        } catch {
            print("Error saving receipt to Firestore: \(error)")
        }
    }
    
    func delete(_ ids: Set<String>) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let collectionPath: String
        
        if appMode == .merchant {
            collectionPath = "merchant_profiles/\(uid)/receipts"
        } else {
            collectionPath = "consumer_data/\(uid)/receipts"
        }
        
        for id in ids {
            do {
                try await db.collection(collectionPath).document(id).delete()
            } catch {
                print("Error deleting receipt \(id) from Firestore: \(error)")
            }
        }
        
        receipts.removeAll { ids.contains($0.stableId) }
    }

    func co2AvoidedThisMonth(kgPerReceipt: Double = 0.1) -> Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let count = receipts.filter { $0.date >= start }.count
        return Double(count) * kgPerReceipt
    }

    func waterSavedInLiters() -> Double {
        let baseWaterPerReceipt = 0.1
        let waterPerItem = 0.08
        
        let totalBase = Double(receipts.count) * baseWaterPerReceipt
        let totalItems = receipts.reduce(0) { $0 + $1.items.count }
        let totalItemWater = Double(totalItems) * waterPerItem
        
        return totalBase + totalItemWater
    }

    func treesSaved() -> Double {
        let baseSheetsPerReceipt = 1.0 / 40.0
        let sheetsPerItem = 1.0 / 200.0
        let sheetsPerTree = 8333.0
        
        let totalBaseSheets = Double(receipts.count) * baseSheetsPerReceipt
        let totalItems = receipts.reduce(0) { $0 + $1.items.count }
        let totalItemSheets = Double(totalItems) * sheetsPerItem
        
        let totalA4SheetsSaved = totalBaseSheets + totalItemSheets
        
        return totalA4SheetsSaved / sheetsPerTree
    }
    
    func addProduct(_ product: ProductItem) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            var newProduct = product
            let ref = try db.collection("merchant_profiles").document(uid).collection("products").addDocument(from: newProduct)
            newProduct.id = ref.documentID
            products.append(newProduct)
        } catch {
            print("Error adding product to Firestore: \(error)")
        }
    }

    func deleteProduct(at offsets: IndexSet) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let productsToDelete = offsets.map { self.products[$0] }
        for product in productsToDelete {
            if let id = product.id {
                do {
                    try await db.collection("merchant_profiles").document(uid).collection("products").document(id).delete()
                } catch {
                    print("Error deleting product \(id) from Firestore: \(error)")
                }
            }
        }
        products.remove(atOffsets: offsets)
    }
    
    func loadMerchantData(uid: String) async {
        do {
            let productSnapshot = try await db.collection("merchant_profiles").document(uid).collection("products").getDocuments()
            self.products = productSnapshot.documents.compactMap { try? $0.data(as: ProductItem.self) }
            
            let receiptSnapshot = try await db.collection("merchant_profiles").document(uid).collection("receipts").getDocuments()
            self.receipts = receiptSnapshot.documents.compactMap { try? $0.data(as: Receipt.self) }
        } catch {
            print("Error loading merchant data: \(error)")
        }
    }
    
    func loadConsumerData(uid: String) async {
        do {
            let receiptSnapshot = try await db.collection("consumer_data").document(uid).collection("receipts").getDocuments()
            self.receipts = receiptSnapshot.documents.compactMap { try? $0.data(as: Receipt.self) }
        } catch {
            print("Error loading consumer receipts: \(error)")
        }
    }
}

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
    static let timeHM: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    static let dateWithTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()
}
