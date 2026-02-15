//
//  DonorCreateJobView.swift
//  Bottle
//

import SwiftUI
import MapKit
import UIKit
import UserNotifications

struct DonorCreateJobView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataService: DataService
    @AppStorage("bottlr.firstRunTip.host") private var showHostTip = true
    let existingPost: BottleJob?
    
    @State private var address = ""
    @State private var bottleCount = ""
    @State private var schedule = "Today"
    @State private var notes = ""
    @State private var isRecurring = false
    @State private var tier: JobTier = .residential
    
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var locationQuery = ""
    @State private var locationResults: [MKMapItem] = []
    @State private var isSearchingLocations = false
    @State private var didLoadDefaultAddress = false
    @State private var defaultAddressValue: String?
    @State private var defaultAddressCoordinate: CLLocationCoordinate2D?
    @State private var saveAsDefaultAddress = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isLocationFieldFocused: Bool
    
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPostedSuccess = false
    @State private var bottlePhotoImage: UIImage?
    @State private var locationPhotoImage: UIImage?
    @State private var showBottleCamera = false
    @State private var showLocationCamera = false
    private let quickBottleCounts = [25, 50, 100, 200, 350]
    private let quickSchedules = ["Now", "Today", "Tonight", "Tomorrow", "This weekend"]
    private let quickContextNotes = ["Dog on site", "Gate code needed", "Use side entrance", "Call on arrival", "Heavy bags"]

    init(existingPost: BottleJob? = nil) {
        self.existingPost = existingPost
        _address = State(initialValue: existingPost?.address ?? "")
        _bottleCount = State(initialValue: existingPost.map { "\($0.bottleCount)" } ?? "")
        _schedule = State(initialValue: existingPost?.schedule ?? "Today")
        _notes = State(initialValue: existingPost?.notes ?? "")
        _isRecurring = State(initialValue: existingPost?.isRecurring ?? false)
        _tier = State(initialValue: existingPost?.tier ?? .residential)
        _coordinate = State(initialValue: existingPost?.coordinate)
        _bottlePhotoImage = State(initialValue: Self.image(fromBase64: existingPost?.bottlePhotoBase64))
        _locationPhotoImage = State(initialValue: Self.image(fromBase64: existingPost?.locationPhotoBase64))
    }
    
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
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            TextField("0", text: $bottleCount)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            Button {
                                adjustBottleCount(by: 5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.brandGreen)
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
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
                    if existingPost == nil, let defaultAddressValue {
                        Button {
                            applyDefaultAddress()
                        } label: {
                            Label("Use saved default address", systemImage: "house.fill")
                                .font(.subheadline)
                        }
                        Text(defaultAddressValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if hasConfirmedAddress {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Address confirmed")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                Button("Change") {
                                    startChangingAddress()
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.brandBlueDark)

                                Button("Clear") {
                                    clearSelectedAddress()
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }

                        if existingPost == nil {
                            Toggle("Save this as my default address", isOn: $saveAsDefaultAddress)
                                .font(.subheadline)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField(hasConfirmedAddress ? "Search for a new address" : "Search address", text: $locationQuery)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Search pickup address")
                            .focused($isLocationFieldFocused)
                            .onChange(of: locationQuery) { _, newValue in
                                // Prevent stale coordinate usage when user edits selected address.
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if hasConfirmedAddress && !trimmed.isEmpty {
                                    coordinate = nil
                                    address = ""
                                }

                                searchTask?.cancel()

                                if trimmed.isEmpty {
                                    locationResults = []
                                    isSearchingLocations = false
                                    return
                                }

                                searchTask = Task {
                                    do {
                                        try await Task.sleep(nanoseconds: 300_000_000)
                                        guard !Task.isCancelled else { return }
                                        await MainActor.run {
                                            searchLocations()
                                        }
                                    } catch {
                                        // Cancelled
                                    }
                                }
                            }

                        if !locationQuery.isEmpty {
                            Button {
                                clearLocationInput()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Clear address search")
                        }
                    }

                    if isSearchingLocations {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Searching locations...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Select one suggestion below to confirm this address.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if !locationResults.isEmpty {
                        ForEach(locationResults.prefix(5), id: \.self) { item in
                            Button {
                                applyLocation(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Location")
                                        .foregroundColor(.primary)
                                    Text(item.placemark.title ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .accessibilityLabel("Use address \(item.placemark.title ?? item.name ?? "Location")")
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
                        Label(bottlePhotoImage == nil ? "Take bottle photo" : "Retake bottle photo", systemImage: "camera.fill")
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
                        Label(locationPhotoImage == nil ? "Take location photo" : "Retake location photo", systemImage: "camera.metering.matrix")
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
                    Button(action: submitPost) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text(existingPost == nil ? "Post" : "Save Changes")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle(existingPost == nil ? "Post Info" : "Edit Post")
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
                Text(existingPost == nil ? "Your collection point request is now visible to nearby collectors." : "Your collection point has been updated.")
            }
            .fullScreenCover(isPresented: $showBottleCamera) {
                CameraImagePicker(image: $bottlePhotoImage)
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showLocationCamera) {
                CameraImagePicker(image: $locationPhotoImage)
                    .ignoresSafeArea()
            }
            .onAppear {
                loadDefaultAddressIfNeeded()
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }
    
    private var canSubmit: Bool {
        (Int(bottleCount) ?? 0) > 0 && coordinate != nil && !address.isEmpty
    }

    private var hasConfirmedAddress: Bool {
        coordinate != nil && !address.isEmpty
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

    private func searchLocations() {
        let query = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            isSearchingLocations = false
            locationResults = []
            return
        }

        isSearchingLocations = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )

        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isSearchingLocations = false
                locationResults = response?.mapItems ?? []
            }
        }
    }

    private func applyLocation(_ item: MKMapItem) {
        coordinate = item.placemark.coordinate
        address = item.placemark.title ?? item.name ?? ""
        locationQuery = ""
        locationResults = []
        isLocationFieldFocused = false
    }

    private func startChangingAddress() {
        locationQuery = ""
        locationResults = []
        isLocationFieldFocused = true
    }

    private func clearSelectedAddress() {
        address = ""
        coordinate = nil
        locationResults = []
    }

    private func clearLocationInput() {
        locationQuery = ""
        clearSelectedAddress()
        isLocationFieldFocused = true
    }
    
    private func submitPost() {
        guard let count = Int(bottleCount), let coordinate else {
            errorMessage = "Please enter valid listing details."
            showError = true
            return
        }
        isSubmitting = true
        Task {
            do {
                if let existingPost {
                    try await dataService.updatePost(
                        existingPost,
                        address: address,
                        location: GeoLocation(coordinate: coordinate),
                        bottleCount: count,
                        schedule: schedule,
                        notes: notes,
                        isRecurring: isRecurring,
                        tier: tier,
                        bottlePhotoBase64: bottlePhotoImage?.jpegData(compressionQuality: 0.6)?.base64EncodedString(),
                        locationPhotoBase64: locationPhotoImage?.jpegData(compressionQuality: 0.6)?.base64EncodedString()
                    )
                } else {
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
                }
                isSubmitting = false
                if existingPost == nil {
                    if saveAsDefaultAddress {
                        persistDefaultAddress(address: address, coordinate: coordinate)
                    }
                    showHostTip = false
                    sendPostNotification(for: count)
                }
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

    private static func image(fromBase64 value: String?) -> UIImage? {
        guard
            let value,
            let data = Data(base64Encoded: value),
            let image = UIImage(data: data)
        else {
            return nil
        }
        return image
    }

    private func loadDefaultAddressIfNeeded() {
        guard existingPost == nil, !didLoadDefaultAddress else { return }
        didLoadDefaultAddress = true

        let defaults = UserDefaults.standard
        let keyPrefix = defaultAddressKeyPrefix()
        guard
            let savedAddress = defaults.string(forKey: "\(keyPrefix).address"),
            !savedAddress.isEmpty
        else {
            defaultAddressValue = nil
            defaultAddressCoordinate = nil
            return
        }

        defaultAddressValue = savedAddress
        let hasLat = defaults.object(forKey: "\(keyPrefix).lat") != nil
        let hasLon = defaults.object(forKey: "\(keyPrefix).lon") != nil
        if hasLat, hasLon {
            let lat = defaults.double(forKey: "\(keyPrefix).lat")
            let lon = defaults.double(forKey: "\(keyPrefix).lon")
            defaultAddressCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        if !hasConfirmedAddress, let defaultAddressCoordinate {
            address = savedAddress
            coordinate = defaultAddressCoordinate
            saveAsDefaultAddress = true
        }
    }

    private func applyDefaultAddress() {
        guard let defaultAddressValue, let defaultAddressCoordinate else { return }
        address = defaultAddressValue
        coordinate = defaultAddressCoordinate
        locationQuery = ""
        locationResults = []
        saveAsDefaultAddress = true
    }

    private func persistDefaultAddress(address: String, coordinate: CLLocationCoordinate2D) {
        let defaults = UserDefaults.standard
        let keyPrefix = defaultAddressKeyPrefix()
        defaults.set(address, forKey: "\(keyPrefix).address")
        defaults.set(coordinate.latitude, forKey: "\(keyPrefix).lat")
        defaults.set(coordinate.longitude, forKey: "\(keyPrefix).lon")
        defaultAddressValue = address
        defaultAddressCoordinate = coordinate
    }

    private func defaultAddressKeyPrefix() -> String {
        let userID = dataService.currentUser?.id ?? "guest"
        return "bottlr.host.defaultAddress.\(userID)"
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
        .environmentObject(DataService.shared)
}
