//
//  DonorCreateJobView.swift
//  Bottle
//

import SwiftUI
import MapKit
import PhotosUI
import UIKit
import UserNotifications

struct DonorCreateJobView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var dataService = DataService.shared
    
    @State private var address = ""
    @State private var bottleCount = ""
    @State private var schedule = "Today"
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
    @State private var showBottleCamera = false
    @State private var showLocationCamera = false
    private let quickBottleCounts = [25, 50, 100, 200, 350]
    private let quickSchedules = ["Now", "Today", "Tonight", "Tomorrow", "This weekend"]
    private let quickContextNotes = ["Dog on site", "Gate code needed", "Use side entrance", "Call on arrival", "Heavy bags"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Post Info") {
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
                
                Section("Pickup Timing") {
                    TextField("Pickup timing (optional)", text: $schedule)
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
                }

                Section("Things To Know (Optional)") {
                    TextField("Anything collectors should know?", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickContextNotes, id: \.self) { item in
                                Button(item) {
                                    appendContextNote(item)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                }

                Section("Photos (Optional)") {
                    Button {
                        showBottleCamera = true
                    } label: {
                        Label("Take bottle photo", systemImage: "camera.fill")
                    }
                    PhotosPicker(selection: $selectedBottlePhoto, matching: .images) {
                        Label("Choose bottle photo from library", systemImage: "photo.on.rectangle")
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
                    Button {
                        showLocationCamera = true
                    } label: {
                        Label("Take location photo", systemImage: "camera.metering.matrix")
                    }
                    PhotosPicker(selection: $selectedLocationPhoto, matching: .images) {
                        Label("Choose location photo from library", systemImage: "mappin.and.ellipse")
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
                                Text("Post")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle("Post Info")
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
                Text("Your collection point request is now visible to nearby collectors.")
            }
            .sheet(isPresented: $showLocationSearchSheet) {
                LocationSearchView(selectedLocation: $selectedLocationResult)
            }
            .fullScreenCover(isPresented: $showBottleCamera) {
                CameraImagePicker(image: $bottlePhotoImage)
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showLocationCamera) {
                CameraImagePicker(image: $locationPhotoImage)
                    .ignoresSafeArea()
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
        (Int(bottleCount) ?? 0) > 0 && coordinate != nil && !address.isEmpty
    }

    private var missingRequirementsText: String {
        var missing: [String] = []
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
                    title: autoPostTitle(for: count),
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
                sendPostNotification(for: count)
                showPostedSuccess = true
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func appendContextNote(_ note: String) {
        if notes.contains(note) { return }
        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes = note
        } else {
            notes += ", \(note)"
        }
    }

    private func autoPostTitle(for count: Int) -> String {
        let name = dataService.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = (name?.isEmpty == false) ? name! : "Community"
        return "\(safeName) • \(count) bottles"
    }

    private func sendPostNotification(for count: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Post is live"
            content.body = "Your \(count)-bottle post is now visible to nearby collectors."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            center.add(request)
        }
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker
        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }
    }
}

#Preview {
    DonorCreateJobView()
}
