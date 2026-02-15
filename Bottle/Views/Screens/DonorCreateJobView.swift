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
    
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var selectedLocationResult: LocationSearchResult?
    @State private var showLocationSearchSheet = false
    
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPostedSuccess = false
    @State private var selectedBottlePhoto: PhotosPickerItem?
    @State private var bottlePhotoImage: UIImage?
    @State private var selectedLocationPhoto: PhotosPickerItem?
    @State private var locationPhotoImage: UIImage?
    @State private var aiSuggestion: String?
    @State private var isAnalyzingPhoto = false
    private let geminiService = GeminiService()
    private let quickBottleCounts = [25, 50, 100, 200, 350]
    private let quickSchedules = ["Today", "Tonight", "This weekend", "Tomorrow morning"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Listing") {
                    TextField("Title (e.g. Apartment bottles pickup)", text: $title)
                    Picker("Tier", selection: $tier) {
                        Text("Residential").tag(JobTier.residential)
                        Text("Bulk").tag(JobTier.bulk)
                        Text("Commercial").tag(JobTier.commercial)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bottle count")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            Button {
                                adjustBottleCount(by: -5)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }

                            TextField("0", text: $bottleCount)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)

                            Button {
                                adjustBottleCount(by: 5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.brandGreen)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickBottleCounts, id: \.self) { count in
                                    Button("+\(count)") {
                                        bottleCount = "\(count)"
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.brandBlueLight.opacity(0.14))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section("Location") {
                    Button {
                        showLocationSearchSheet = true
                    } label: {
                        Label(address.isEmpty ? "Search & Select Address" : "Change Address", systemImage: "magnifyingglass")
                    }

                    if !address.isEmpty, let coordinate {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(address, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Lat \(String(format: "%.4f", coordinate.latitude)), Lon \(String(format: "%.4f", coordinate.longitude))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Details") {
                    TextField("Schedule", text: $schedule)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickSchedules, id: \.self) { option in
                                Button(option) {
                                    schedule = option
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                    Toggle("Recurring", isOn: $isRecurring)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("AI Impact Estimate (Optional)") {
                    PhotosPicker(selection: $selectedBottlePhoto, matching: .images) {
                        Label("Add bottles photo", systemImage: "camera.fill")
                    }
                    if let bottlePhotoImage {
                        Image(uiImage: bottlePhotoImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(10)
                    }
                    PhotosPicker(selection: $selectedLocationPhoto, matching: .images) {
                        Label("Add pickup location photo", systemImage: "mappin.and.ellipse")
                    }
                    if let locationPhotoImage {
                        Image(uiImage: locationPhotoImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(10)
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
                    if !canSubmit {
                        Text(missingRequirementsText)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Button(action: create) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Post Listing")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle("Post Impact")
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
            .alert("Listing posted", isPresented: $showPostedSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your impact request is now visible to nearby collectors.")
            }
            .sheet(isPresented: $showLocationSearchSheet) {
                LocationSearchView(selectedLocation: $selectedLocationResult)
            }
            .onChange(of: selectedLocationResult) { _, newValue in
                guard let newValue else { return }
                coordinate = newValue.coordinate
                address = newValue.address
            }
            .onChange(of: selectedBottlePhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        bottlePhotoImage = image
                        await analyzePhotoWithGemini(image)
                    }
                }
            }
            .onChange(of: selectedLocationPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        locationPhotoImage = image
                    }
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        !title.isEmpty && (Int(bottleCount) ?? 0) > 0 && coordinate != nil && !address.isEmpty
    }

    private var missingRequirementsText: String {
        var missing: [String] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("title") }
        if (Int(bottleCount) ?? 0) <= 0 { missing.append("bottle count") }
        if coordinate == nil || address.isEmpty { missing.append("location") }
        if missing.isEmpty { return "" }
        return "Complete: \(missing.joined(separator: ", "))."
    }

    private func adjustBottleCount(by delta: Int) {
        let current = max(0, Int(bottleCount) ?? 0)
        bottleCount = "\(max(0, current + delta))"
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
                    availableTime: schedule,
                    bottlePhotoBase64: bottlePhotoImage?.jpegData(compressionQuality: 0.6)?.base64EncodedString(),
                    locationPhotoBase64: locationPhotoImage?.jpegData(compressionQuality: 0.6)?.base64EncodedString()
                )
                isSubmitting = false
                showPostedSuccess = true
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
            let materialsText: String
            if let materials = countResult.materials {
                materialsText = " • mix P\(materials.plastic)/A\(materials.aluminum)/G\(materials.glass)"
            } else {
                materialsText = ""
            }
            let estimatedCo2 = ClimateImpactCalculator.co2Saved(bottles: countResult.count)
            aiSuggestion = "Gemini confidence \(countResult.confidence)%\(materialsText) • \(recycleResult.summary) • estimated climate impact: \(String(format: "%.1f", estimatedCo2)) kg CO₂ diverted."
        } catch {
            aiSuggestion = "Gemini estimate unavailable. You can still post and create impact manually."
        }
    }
}

#Preview {
    DonorCreateJobView()
}
