//
//  ProfileView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var mockData = MockDataService.shared
    @State private var logoTapCount = 0
    @State private var showDemoPanel = false
    
    private var profile: UserProfile {
        mockData.currentUser
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
                                .fill(Color(hex: "00C853").opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Text(profile.name.prefix(1))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color(hex: "00C853"))
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
                            }
                            
                            Text("Member since \(profile.joinDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Quick Stats
                        HStack(spacing: 20) {
                            ProfileStatPill(value: "\(profile.totalBottles)", label: "Bottles")
                            ProfileStatPill(value: "$\(Int(profile.totalEarnings))", label: "Earned")
                            ProfileStatPill(value: "\(profile.badges.count)", label: "Badges")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        ProfileMenuItem(icon: "person.fill", title: "Edit Profile", color: Color(hex: "00C853"))
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "bell.fill", title: "Notifications", color: Color(hex: "FF9800"))
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "creditcard.fill", title: "Payment Methods", color: Color(hex: "2196F3"))
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "chart.bar.fill", title: "Statistics", color: Color(hex: "9C27B0"))
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "gearshape.fill", title: "Settings", color: .gray)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ABOUT BOTTLR")
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
                    
                    // App Info
                    VStack(spacing: 8) {
                        Button(action: {}) {
                            Text("Terms of Service")
                                .font(.caption)
                                .foregroundColor(Color(hex: "00C853"))
                        }
                        
                        Button(action: {}) {
                            Text("Privacy Policy")
                                .font(.caption)
                                .foregroundColor(Color(hex: "00C853"))
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
                .foregroundColor(Color(hex: "00C853"))
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
