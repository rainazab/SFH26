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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Rating \(String(format: "%.1f", profile.rating)) out of 5 stars")
                            
                            Text("Member since \(profile.joinDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: profile.totalBottles))) kg CO₂ saved")
                                .font(.caption)
                                .foregroundColor(.brandBlueLight)

                            HStack(spacing: 10) {
                                Label("\(Int(profile.reliabilityScore))% reliable", systemImage: "checkmark.shield.fill")
                                    .font(.caption2)
                                    .foregroundColor(.brandGreen)
                                Label("\(Int(profile.onTimeRate))% on-time", systemImage: "clock.badge.checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.brandBlueLight)
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
                            ProfileStatPill(value: "\(profile.badges.count)", label: "Impact Badges")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACTIVITY TIMELINE")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if dataService.activityTimeline.isEmpty {
                            Text("No activity yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        ProfileMenuItem(icon: "person.fill", title: "Edit Profile", color: .brandGreen)
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            NotificationSettingsPanel()
                        } label: {
                            ProfileMenuRow(icon: "bell.fill", title: "Notifications", color: Color(hex: "FF9800"))
                        }
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "creditcard.fill", title: "Payment Methods", color: .brandBlueLight)
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "chart.bar.fill", title: "Statistics", color: .tierCommercial)
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "gearshape.fill", title: "Settings", color: .gray)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)

                    #if DEBUG
                    Button("Open Demo Controls") {
                        showDemoPanel = true
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                    #endif
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ABOUT bottlr")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            AboutRow(icon: "leaf.circle.fill", title: "Our Mission", description: "Connecting collectors with hosts to build a sustainable, dignified recycling network")
                            Divider()
                            AboutRow(icon: "heart.circle.fill", title: "Social Impact", description: "Supporting 150K+ collectors across California")
                            Divider()
                            AboutRow(icon: "info.circle.fill", title: "How It Works", description: "Hosts create posts, collectors claim collection points, everyone benefits")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Backend")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dataService.backendStatus == "firestore" ? "Firestore live sync active" : "Local mode active")
                            .font(.subheadline)
                            .foregroundColor(dataService.backendStatus == "firestore" ? .green : .orange)
                        if let syncError = dataService.lastSyncError {
                            Text(syncError)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

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
                    .padding()
                    
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
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
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

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
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

struct AboutRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.brandGreen)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
        .environmentObject(DataService.shared)
}
