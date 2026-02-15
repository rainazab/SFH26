//
//  ProfileView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import PhotosUI
import UIKit
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var showDemoPanel = false
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var pendingProfileImage: UIImage?
    @State private var isUploadingProfilePhoto = false
    
    private var profile: UserProfile {
        dataService.currentUser ?? UserProfile.mockCollector
    }

    private var hasReliabilityData: Bool {
        profile.reviewCount > 0 || !dataService.completedJobs.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.brandGreen.opacity(0.2))
                                .frame(width: 100, height: 100)

                            if let previewImage = pendingProfileImage ?? profileImage {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Text(profile.name.prefix(1))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(Color.brandGreen)
                            }

                            Circle()
                                .stroke(Color.white.opacity(0.75), lineWidth: 2)
                                .frame(width: 100, height: 100)
                        }

                        PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                            HStack(spacing: 6) {
                                if isUploadingProfilePhoto {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "camera.fill")
                                }
                                Text(isUploadingProfilePhoto ? "Updating photo..." : "Change profile photo")
                            }
                            .font(.caption)
                            .foregroundColor(.brandGreen)
                        }
                        .accessibilityLabel("Change profile photo")
                        
                        VStack(spacing: 8) {
                            Text(profile.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 4) {
                                if max(profile.reviewCount, dataService.completedJobs.count) == 0 {
                                    Text("No ratings yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < Int(profile.rating) ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .font(.subheadline)
                                    }
                                    Text(String(format: "%.1f", profile.rating))
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("(\(max(profile.reviewCount, dataService.completedJobs.count)) reviews)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(max(profile.reviewCount, dataService.completedJobs.count) == 0 ? "No ratings yet" : "Rating \(String(format: "%.1f", profile.rating)) out of 5 stars")
                            
                            Text("Member since \(profile.joinDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: profile.totalBottles))) kg CO₂ saved")
                                .font(.caption)
                                .foregroundColor(.brandBlueLight)

                            if hasReliabilityData {
                                HStack(spacing: 10) {
                                    Label("\(Int(profile.reliabilityScore))% reliable", systemImage: "checkmark.shield.fill")
                                        .font(.caption2)
                                        .foregroundColor(.brandGreen)
                                    Label("\(Int(profile.onTimeRate))% on-time", systemImage: "clock.badge.checkmark")
                                        .font(.caption2)
                                        .foregroundColor(.brandBlueLight)
                                }
                            } else {
                                Text("Reliability data appears after your first completed pickup.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 10) {
                                Text("Cancellations: \(profile.cancellationCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Disputes: \(profile.disputeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Quick Stats
                        HStack(spacing: 20) {
                            ProfileStatPill(value: "\(profile.totalBottles)", label: "Bottles")
                            ProfileStatPill(value: "\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: profile.totalBottles)))kg", label: "CO₂ Saved")
                        }
                    }
                    .padding(18)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACTIVITY TIMELINE")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if dataService.activityTimeline.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text("No activity yet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(Array(dataService.activityTimeline.prefix(6))) { event in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(colorForEvent(event.type))
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 5)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .font(.subheadline)
                                        if let bottles = event.bottles {
                                            Text("\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: bottles))) kg CO₂ • \(bottles) bottles")
                                                .font(.caption)
                                                .foregroundColor(.brandBlueLight)
                                        } else if let amount = event.amount {
                                            Text("Estimated value: $\(String(format: "%.2f", amount))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                if event.id != dataService.activityTimeline.prefix(6).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        NavigationLink {
                            EditProfilePanel()
                                .environmentObject(authService)
                                .environmentObject(dataService)
                        } label: {
                            ProfileMenuRow(icon: "person.fill", title: "Edit Profile", color: .brandGreen)
                        }
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            NotificationSettingsPanel()
                        } label: {
                            ProfileMenuRow(icon: "bell.fill", title: "Notifications", color: Color(hex: "FF9800"))
                        }
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            SettingsPanel()
                        } label: {
                            ProfileMenuRow(icon: "gearshape.fill", title: "Settings", color: .gray)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    
                    // App Info
                    VStack(spacing: 8) {
                        Button(action: {}) {
                            Text("Terms of Service")
                                .font(.caption)
                                .foregroundColor(Color.brandGreen)
                        }
                        
                        Button(action: {}) {
                            Text("Privacy Policy")
                                .font(.caption)
                                .foregroundColor(Color.brandGreen)
                        }
                        
                        Text("Version 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Made with ♻️ in San Francisco")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Sign Out
                    Button(action: {
                        do {
                            try authService.signOut()
                        } catch {
                            // Keep UX simple in demo mode; authService publishes state.
                        }
                    }) {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(15)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Profile")
            .background(Color(.systemGray6))
            .sheet(isPresented: $showDemoPanel) {
                DemoControlPanel()
            }
            .onChange(of: selectedProfilePhoto) { _, newValue in
                Task {
                    guard let newValue else { return }
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pendingProfileImage = image
                        isUploadingProfilePhoto = true
                        do {
                            try await authService.updateProfilePhoto(image)
                        } catch {
                            isUploadingProfilePhoto = false
                        }
                    } else {
                        authService.errorMessage = "Couldn't load that photo. Please try a different image."
                    }
                }
            }
            .onChange(of: profile.profilePhotoUrl) { _, _ in
                pendingProfileImage = nil
                isUploadingProfilePhoto = false
            }
        }
        .navigationViewStyle(.stack)
    }

    private var profileImage: UIImage? {
        guard let reference = profile.profilePhotoUrl else { return nil }

        if reference.hasPrefix("file://"),
           let url = URL(string: reference),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }

        if let data = Data(base64Encoded: reference),
           let image = UIImage(data: data) {
            return image
        }

        return nil
    }

    private func colorForEvent(_ type: ActivityType) -> Color {
        switch type {
        case .pickupCompleted: return .brandBlueLight
        case .earningsAdded: return .brandGreen
        case .badgeEarned: return .accentGold
        }
    }
}

struct ProfileStatPill: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct NotificationSettingsPanel: View {
    @State private var newPostAlerts = AppNotificationService.shared.newPostAlertsEnabled
    @State private var pickupAlerts = AppNotificationService.shared.pickupAlertsEnabled
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("New nearby posts", isOn: $newPostAlerts)
                    .onChange(of: newPostAlerts) { _, value in
                        AppNotificationService.shared.newPostAlertsEnabled = value
                    }
                Toggle("Post updates (claimed/completed)", isOn: $pickupAlerts)
                    .onChange(of: pickupAlerts) { _, value in
                        AppNotificationService.shared.pickupAlertsEnabled = value
                    }
            }

            Section("System Permission") {
                Text(permissionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Request Notification Permission") {
                    AppNotificationService.shared.requestPermissionIfNeeded()
                    refreshAuthorizationStatus()
                }
            }

            Section("FAQ") {
                FAQRow(
                    question: "Why am I not getting alerts?",
                    answer: "Enable notifications in iOS Settings and keep \"New nearby posts\" turned on."
                )
                FAQRow(
                    question: "What notifications will I get?",
                    answer: "You can receive nearby post alerts and post update alerts (claimed/completed)."
                )
            }
        }
        .navigationTitle("Notifications")
        .onAppear {
            refreshAuthorizationStatus()
        }
    }

    private var permissionDescription: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are enabled on this device."
        case .denied:
            return "Notifications are disabled in iOS Settings for bottlr."
        case .notDetermined:
            return "Allow notifications so you can jump directly to new collection points."
        @unknown default:
            return "Notification permission status is unknown."
        }
    }

    private func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                authorizationStatus = settings.authorizationStatus
            }
        }
    }
}

struct EditProfilePanel: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var displayName: String = ""
    @State private var showSaved = false

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $displayName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Button("Save Changes") {
                    let userType = dataService.currentUser?.type ?? .collector
                    authService.completeOnboarding(name: displayName, userType: userType)
                    showSaved = true
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("FAQ") {
                FAQRow(
                    question: "Can I change my role later?",
                    answer: "Role changes are supported via account/profile flow and are persisted."
                )
                FAQRow(
                    question: "Why update my display name?",
                    answer: "Collectors and hosts see this name on posts and verification steps."
                )
            }
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            displayName = dataService.currentUser?.name ?? ""
        }
        .alert("Saved", isPresented: $showSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your profile was updated.")
        }
    }
}

struct SettingsPanel: View {
    @AppStorage("bottlr.settings.aiEnabled") private var aiEnabled = AppConfig.aiVerificationEnabled
    @AppStorage("bottlr.settings.climateAnimations") private var climateAnimations = AppConfig.climateAnimationEnabled

    var body: some View {
        Form {
            Section("App") {
                Toggle("Enable AI Verification", isOn: $aiEnabled)
                    .onChange(of: aiEnabled) { _, value in
                        AppConfig.aiVerificationEnabled = value
                    }
                Toggle("Enable Climate Animations", isOn: $climateAnimations)
                    .onChange(of: climateAnimations) { _, value in
                        AppConfig.climateAnimationEnabled = value
                    }
            }

            Section("System") {
                Button("Open iOS App Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }

            Section("FAQ") {
                FAQRow(
                    question: "What does AI Verification do?",
                    answer: "It uses image analysis to estimate bottle counts and materials before completion."
                )
                FAQRow(
                    question: "Can I change settings later?",
                    answer: "Yes, all toggles here are saved and can be updated anytime."
                )
            }
        }
        .navigationTitle("Settings")
    }
}

struct FAQRow: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(answer)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
        .environmentObject(DataService.shared)
}
