//
//  DonorCreateJobView.swift
//  Bottle
//

import SwiftUI
import MapKit
import PhotosUI
import UIKit

struct DonorCreateJobView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var dataService = DataService.shared
    
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
    @State private var selectedLocationResult: LocationSearchResult?
    @State private var isSearching = false
    @State private var showLocationSearchSheet = false
    
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var aiSuggestion: String?
    @State private var isAnalyzingPhoto = false
    private let geminiService = GeminiService()
    
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
                    Button("Open Location Search") {
                        showLocationSearchSheet = true
                    }
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

                Section("AI Estimate (Optional)") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Add bottle photo", systemImage: "camera.fill")
                    }
                    if isAnalyzingPhoto {
                        ProgressView("Analyzing with Gemini...")
                    }
                    if let aiSuggestion {
                        Text(aiSuggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
            .sheet(isPresented: $showLocationSearchSheet) {
                LocationSearchView(selectedLocation: $selectedLocationResult)
            }
            .onChange(of: selectedLocationResult) { _, newValue in
                guard let newValue else { return }
                coordinate = newValue.coordinate
                address = newValue.address
                searchText = newValue.name
                results = []
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photoImage = image
                        await analyzePhotoWithGemini(image)
                    }
                }
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
                try await dataService.createJob(
                    title: title,
                    address: address,
                    location: GeoLocation(coordinate: coordinate),
                    bottleCount: count,
                    schedule: schedule,
                    notes: notes,
                    isRecurring: isRecurring,
                    tier: tier,
                    availableTime: schedule
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

    private func analyzePhotoWithGemini(_ image: UIImage) async {
        isAnalyzingPhoto = true
        defer { isAnalyzingPhoto = false }
        do {
            async let countTask = geminiService.countBottles(from: image)
            async let recycleTask = geminiService.classifyRecyclability(from: image)
            let countResult = try await countTask
            let recycleResult = try await recycleTask
            bottleCount = "\(countResult.count)"
            aiSuggestion = "Gemini: \(recycleResult.summary) • CRV likely: \(recycleResult.isRecyclable ? "Yes" : "No") • est. value: $\(String(format: "%.2f", recycleResult.estimatedValue))."
        } catch {
            aiSuggestion = "Gemini estimate unavailable. You can still post manually."
        }
    }
}

#Preview {
    DonorCreateJobView()
}
