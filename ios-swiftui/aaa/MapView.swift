import SwiftUI
import MapKit

struct MapView: View {
    let address: String
    
    enum MapState {
        case loading
        case success(region: MKCoordinateRegion)
        case failed(error: Error)
    }
    
    @State private var mapState: MapState = .loading
    
    struct Location: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }
    @State private var annotationItems: [Location] = []

    var body: some View {
        VStack {
            switch mapState {
            case .loading:
                ProgressView("Loading Map...")
                
            case .success(let region):
                Map(coordinateRegion: .constant(region), annotationItems: annotationItems) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
                
            case .failed(let error):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Could not load map")
                        .font(.headline)
                    Text("The address might be invalid or there was a network issue.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear(perform: geocodeAddress)
        .navigationTitle("Store Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func geocodeAddress() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding failed: \(error.localizedDescription)")
                self.mapState = .failed(error: error)
                return
            }
            
            guard let location = placemarks?.first?.location else {
                let noLocationError = NSError(domain: "com.yourapp.geocode", code: 1, userInfo: [NSLocalizedDescriptionKey: "No location found for the provided address."])
                print(noLocationError.localizedDescription)
                self.mapState = .failed(error: noLocationError)
                return
            }
            
            let coordinate = location.coordinate
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            self.mapState = .success(region: region)
            self.annotationItems = [Location(coordinate: coordinate)]
        }
    }
}
