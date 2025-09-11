import SwiftUI
import PhotosUI
import QuickLook
import Vision

struct MenuView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var showScanner = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var scanMessage: String? = nil

    var scanURL: URL? {
        guard let s = scanMessage, let u = URL(string: s),
              ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { return nil }
        return u
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan QR (Camera)", systemImage: "qrcode.viewfinder")
                }

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Scan QR from Photo", systemImage: "photo.on.rectangle")
                }
                .onChange(of: pickedItem) { _, newVal in
                    guard let item = newVal else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let ui = UIImage(data: data) {
                            detectBarcodeStrings(in: ui) { results in
                                if let result = results.first {
                                    processScannedResult(result)
                                } else {
                                    scanMessage = "QR/Barcode not found."
                                }
                            }
                        } else {
                            scanMessage = "Failed to load image."
                        }
                    }
                }
                
                Label("Settings (placeholder)", systemImage: "gear")
            }
            .navigationTitle("Menu")
            .fullScreenCover(isPresented: $showScanner) {
                QRScannerSheet(onResult: { result in
                    processScannedResult(result)
                    showScanner = false
                }, onCancel: {
                    showScanner = false
                })
                .ignoresSafeArea()
            }
            .alert("Scan Result", isPresented: Binding(get: { scanMessage != nil }, set: { if !$0 { scanMessage = nil } })) {
                if let url = scanURL {
                    Button("Open Link") { UIApplication.shared.open(url) }
                }
                if let s = scanMessage {
                    Button("Copy") { UIPasteboard.general.string = s }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(scanMessage ?? "")
            }
        }
    }

    private func processScannedResult(_ result: String) {
        if let jsonData = result.data(using: .utf8) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                var newReceipt = try decoder.decode(Receipt.self, from: jsonData)
                newReceipt.id = UUID().uuidString
                newReceipt.tags = newReceipt.payment == .qr ? ["QR"] : []

                Task {
                    await store.add(newReceipt)
                }
                scanMessage = "New receipt added: \(newReceipt.merchant) - \(newReceipt.amount)"
            } catch {
                scanMessage = "Decoding failed: \(error.localizedDescription)"
                
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        scanMessage = "Decoding failed: JSON key '\(key.stringValue)' not found. - \(context.debugDescription)"
                    case .typeMismatch(let type, let context):
                        scanMessage = "Decoding failed: Type '\(type)' mismatch. - \(context.debugDescription)"
                    case .valueNotFound(let type, let context):
                        scanMessage = "Decoding failed: Value for type '\(type)' not found. - \(context.debugDescription)"
                    case .dataCorrupted(let context):
                        scanMessage = "Decoding failed: Data is corrupted. - \(context.debugDescription)"
                    @unknown default:
                        break
                    }
                }
            }
        } else {
            scanMessage = "Not a valid QR code text."
        }
    }
}
