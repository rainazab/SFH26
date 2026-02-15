//
//  LocationSearchView.swift
//  bottlr
//

import SwiftUI
import MapKit

struct LocationSearchResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

struct LocationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: LocationSearchResult?
    
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("Search address", text: $query)
                        .onChange(of: query) { _, _ in search() }
                }
                
                if isSearching {
                    ProgressView("Searching...")
                } else {
                    ForEach(results, id: \.self) { item in
                        Button {
                            selectedLocation = LocationSearchResult(
                                name: item.name ?? "Location",
                                address: item.placemark.title ?? "",
                                coordinate: item.placemark.coordinate
                            )
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Location")
                                    .foregroundColor(.primary)
                                Text(item.placemark.title ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Find Location")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func search() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            return
        }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isSearching = false
                results = response?.mapItems ?? []
            }
        }
    }
}

#Preview {
    LocationSearchView(selectedLocation: .constant(nil))
}
