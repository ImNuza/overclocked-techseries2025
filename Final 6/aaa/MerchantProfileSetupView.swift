import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

struct MerchantProfileSetupView: View {
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss

    @State private var merchantName: String
    @State private var location: String
    @State private var address: String
    @State private var selectedCurrency: Currency
    @State private var selectedGreenTags: Set<GreenTag>
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logoImageData: Data?

    private var existingProfile: MerchantProfile?
    
    init(profile: MerchantProfile? = nil) {
        self.existingProfile = profile
        _merchantName = State(initialValue: profile?.merchantName ?? "")
        _location = State(initialValue: profile?.location ?? "")
        _address = State(initialValue: profile?.address ?? "")
        _selectedCurrency = State(initialValue: profile?.defaultCurrency ?? .usd)
        _logoImageData = State(initialValue: profile?.logoImageData)
        _selectedGreenTags = State(initialValue: Set(profile?.greenTags ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Store Info") {
                    TextField("Store Name (Required)", text: $merchantName)
                    TextField("Location (e.g., City)", text: $location)
                    TextField("Full Address (Optional)", text: $address)
                    Picker("Default Currency", selection: $selectedCurrency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                }
                
                Section("Store Logo") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        Label("Select Logo", systemImage: "photo")
                    }
                    
                    if let logoData = logoImageData, let uiImage = UIImage(data: logoData) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                Section(header: Text("Eco-Friendly Features (Green Tags)")) {
                    ForEach(GreenTag.allCases) { tag in
                        Button(action: {
                            if selectedGreenTags.contains(tag) {
                                selectedGreenTags.remove(tag)
                            } else {
                                selectedGreenTags.insert(tag)
                            }
                        }) {
                            HStack {
                                Image(systemName: tag.icon)
                                Text(tag.rawValue)
                                Spacer()
                                if selectedGreenTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle(existingProfile == nil ? "Create Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if existingProfile != nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile(); dismiss() }
                        .disabled(merchantName.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        logoImageData = data
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in.")
            return
        }

        let updatedProfile = MerchantProfile(
            id: uid,
            merchantName: merchantName,
            location: location.isEmpty ? nil : location,
            address: address.isEmpty ? nil : address,
            logoImageData: logoImageData,
            defaultCurrency: selectedCurrency,
            greenTags: Array(selectedGreenTags),
            hasGreenTags: !selectedGreenTags.isEmpty
        )
        
        let db = Firestore.firestore()
        do {
            try db.collection("merchant_profiles").document(uid).setData(from: updatedProfile, merge: true)
            store.merchantProfile = updatedProfile
        } catch {
            print("Error saving profile to Firestore: \(error.localizedDescription)")
        }
    }
}
