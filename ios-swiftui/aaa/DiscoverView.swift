import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var store: ReceiptStore
    
    @State private var selectedProfileForMap: MerchantProfile?
    
    private var greenStores: [MerchantProfile] {
        if let profile = store.merchantProfile, !profile.greenTags.isEmpty {
            return [profile]
        }
        return []
    }
    
    var body: some View {
        NavigationStack {
            List(greenStores) { profile in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
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
                    
                    HStack {
                        ForEach(profile.greenTags) { tag in
                            Label(tag.rawValue, systemImage: tag.icon)
                                .font(.caption)
                                .padding(5)
                                .background(Color("ThemeGreen").opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Discover Green Stores")
            .sheet(item: $selectedProfileForMap) { profile in
                if let address = profile.address {
                    NavigationStack {
                        MapView(address: address)
                    }
                }
            }
        }
    }
}
