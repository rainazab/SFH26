//
//  ProfileView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var dataService = DataService.shared
    @State private var logoTapCount = 0
    @State private var showDemoPanel = false
    @State private var selectedProfilePhoto: PhotosPickerItem?
    
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

                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
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
                        .onTapGesture {
                            logoTapCount += 1
                            if logoTapCount >= 5 {
                                showDemoPanel = true
                                logoTapCount = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                logoTapCount = 0
                            }
                        }

                        PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                            Label("Change profile photo", systemImage: "camera.fill")
                                .font(.caption)
                                .foregroundColor(.brandGreen)
                        }
                        
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
                        ProfileMenuItem(icon: "bell.fill", title: "Notifications", color: Color(hex: "FF9800"))
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
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ABOUT bottlr")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            AboutRow(icon: "leaf.circle.fill", title: "Our Mission", description: "Connecting collectors with bottle donors to build a sustainable, dignified economy")
                            Divider()
                            AboutRow(icon: "heart.circle.fill", title: "Social Impact", description: "Supporting 150K+ collectors across California")
                            Divider()
                            AboutRow(icon: "info.circle.fill", title: "How It Works", description: "Donors post bottles, collectors claim jobs, everyone benefits")
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
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        authService.updateProfilePhoto(image)
                    }
                }
            }
        }
    }

    private var profileImage: UIImage? {
        guard let base64 = profile.profilePhotoUrl,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
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
}
