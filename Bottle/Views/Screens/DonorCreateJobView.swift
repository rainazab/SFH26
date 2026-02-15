//
//  DonorCreateJobView.swift
//  Bottle
//

import SwiftUI
import MapKit

struct DonorCreateJobView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var mockData = MockDataService.shared
    
    @State private var title = ""
    @State private var address = ""
    @State private var bottleCount = ""
    @State private var schedule = "This weekend"
    @State private var notes = ""
    @State private var isRecurring = false
    @State private var tier: JobTier = .residential
    
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isSearching = false
    
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Listing") {
                    TextField("Title", text: $title)
                    Picker("Tier", selection: $tier) {
                        Text("Residential").tag(JobTier.residential)
                        Text("Bulk").tag(JobTier.bulk)
                        Text("Commercial").tag(JobTier.commercial)
                    }
                    TextField("Bottle count", text: $bottleCount)
                        .keyboardType(.numberPad)
                }
                
                Section("Location") {
                    TextField("Search address", text: $searchText)
                        .onChange(of: searchText) { _, _ in searchLocation() }
                    if isSearching {
                        ProgressView()
                    }
                    ForEach(results, id: \.self) { item in
                        Button(item.name ?? item.placemark.title ?? "Location") {
                            select(item)
                        }
                    }
                    if !address.isEmpty {
                        Label(address, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section("Details") {
                    TextField("Schedule", text: $schedule)
                    Toggle("Recurring", isOn: $isRecurring)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Button(action: create) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Create Listing")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle("New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var canSubmit: Bool {
        !title.isEmpty && (Int(bottleCount) ?? 0) > 0 && coordinate != nil && !address.isEmpty
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else {
            results = []
            return
        }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
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
    
    private func select(_ item: MKMapItem) {
        coordinate = item.placemark.coordinate
        address = item.placemark.title ?? item.name ?? ""
        results = []
        searchText = item.name ?? searchText
    }
    
    private func create() {
        guard let count = Int(bottleCount), let coordinate else {
            errorMessage = "Please enter valid listing details."
            showError = true
            return
        }
        isSubmitting = true
        Task {
            do {
                try await mockData.createDonorJob(
                    title: title,
                    address: address,
                    coordinate: coordinate,
                    bottleCount: count,
                    schedule: schedule,
                    notes: notes,
                    isRecurring: isRecurring,
                    tier: tier
                )
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    DonorCreateJobView()
}
