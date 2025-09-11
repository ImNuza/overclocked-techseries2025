import SwiftUI
import FirebaseFirestore

struct DiscoverView: View {
    @State private var greenStores: [MerchantProfile] = []
    @State private var isLoading = true
    @State private var selectedProfileForMap: MerchantProfile?
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading Green Stores...")
                } else if greenStores.isEmpty {
                    Text("No Green Stores Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    List(greenStores) { profile in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                if let logo = profile.logoImage {
                                    Image(uiImage: logo)
                                        .resizable().scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "storefront.circle.fill")
                                        .font(.largeTitle)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.secondary)
                                }
                                VStack(alignment: .leading) {
                                    Text(profile.merchantName)
                                        .font(.headline)
                                    if let location = profile.location {
                                        Text(location)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if let address = profile.address, !address.isEmpty {
                                Button(action: {
                                    selectedProfileForMap = profile
                                }) {
                                    HStack {
                                        Image(systemName: "map.fill")
                                        Text(address)
                                            .lineLimit(1)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if !profile.greenTags.isEmpty {
                                FlowLayout(data: profile.greenTags, id: \.self, spacing: 8) { tag in
                                    Label(tag.rawValue, systemImage: tag.icon)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color("ThemeGreen").opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Discover Green Stores")
            .onAppear(perform: fetchGreenStores)
            .sheet(item: $selectedProfileForMap) { profile in
                if let address = profile.address {
                    NavigationStack {
                        MapView(address: address)
                    }
                }
            }
        }
    }
    
    private func fetchGreenStores() {
        isLoading = true
        let db = Firestore.firestore()
        
        db.collection("merchant_profiles").whereField("hasGreenTags", isEqualTo: true).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching green stores: \(error)")
                isLoading = false
                return
            }
            
            if let snapshot = snapshot {
                self.greenStores = snapshot.documents.compactMap { doc in
                    try? doc.data(as: MerchantProfile.self)
                }
            }
            isLoading = false
        }
    }
}
