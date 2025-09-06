import SwiftUI
import PhotosUI

struct AddReceiptSelectionView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss
    
    @State private var showingCameraScanner = false
    @State private var showingManualEntry = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var scanMessage: String? = nil
    @State private var scanSucceeded = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingCameraScanner = true
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
                                        scanSucceeded = false
                                        scanMessage = "QR/Barcode not found."
                                    }
                                }
                            } else {
                                scanSucceeded = false
                                scanMessage = "Failed to load image."
                            }
                        }
                    }

                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Manual Entry", systemImage: "square.and.pencil")
                    }
                }
            }
            .navigationTitle("Add Receipt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingCameraScanner) {
                QRScannerSheet(onResult: { result in
                    processScannedResult(result)
                    showingCameraScanner = false
                }, onCancel: {
                    showingCameraScanner = false
                })
            }
            .sheet(isPresented: $showingManualEntry) {
                NewReceiptView()
            }
            .alert("Scan Result", isPresented: Binding(get: { scanMessage != nil }, set: { if !$0 { scanMessage = nil } })) {
                Button("OK", role: .cancel) {
                    if scanSucceeded {
                        dismiss()
                    }
                }
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
                let payload = try decoder.decode(QRCodePayload.self, from: jsonData)
                
                let newReceipt = Receipt(
                    id: payload.id ?? UUID().uuidString,
                    merchant: payload.merchant,
                    location: payload.location,
                    amount: payload.amount,
                    date: payload.date,
                    category: payload.category,
                    payment: payload.payment,
                    tags: payload.tags,
                    items: payload.items,
                    notes: payload.notes,
                    currency: payload.currency
                )

                store.add(newReceipt)
                scanMessage = "New receipt added: \(newReceipt.merchant)"
                scanSucceeded = true
            } catch {
                scanMessage = "Decoding failed: \(error.localizedDescription)"
                scanSucceeded = false
            }
        } else {
            scanMessage = "Not a valid QR code text."
            scanSucceeded = false
        }
    }
}
