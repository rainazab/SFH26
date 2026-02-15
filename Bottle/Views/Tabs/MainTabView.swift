//
//  MainTabView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import CoreLocation

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    @StateObject private var dataService = DataService.shared
    @State private var selectedTab = 0
    @State private var showLocationPrompt = false
    
    private var userType: UserType {
        dataService.currentUser?.type ?? .collector
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Map View (Primary for Collectors)
            MapView()
                .tabItem {
                    Label("Explore", systemImage: "map.fill")
                }
                .tag(0)
            
            // Post/List View
            if userType == .donor {
                DonorHomeView()
                    .tabItem {
                        Label("Donate", systemImage: "plus.circle.fill")
                    }
                    .tag(1)
            } else {
                JobListView()
                    .tabItem {
                        Label("Jobs", systemImage: "list.bullet")
                    }
                    .tag(1)
            }
            
            // Activity/History
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "clock.fill")
                }
                .tag(2)
            
            // Impact/Stats
            ImpactView()
                .tabItem {
                    Label("Impact", systemImage: "chart.bar.fill")
                }
                .tag(3)
            
            // Profile
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(Color.brandGreen)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.shared.selection()
        }
        .onAppear {
            if locationService.authorizationStatus == .notDetermined {
                showLocationPrompt = true
            } else if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                locationService.startUpdatingLocation()
            }
        }
        .onChange(of: locationService.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationService.startUpdatingLocation()
            }
        }
        .onChange(of: locationService.userLocation) { _, location in
            if let coordinate = location?.coordinate {
                dataService.updateJobDistances(from: coordinate)
            }
        }
        .alert("Enable Location", isPresented: $showLocationPrompt) {
            Button("Not Now", role: .cancel) {}
            Button("Enable") {
                locationService.requestPermission()
            }
        } message: {
            Text("bottlr uses your location to show nearby jobs and sort pickups around you.")
        }
    }
}

struct RoleSelectionView: View {
    let onSelect: (UserType) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("How will you use bottlr?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("Choose your role to personalize your experience.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    onSelect(.collector)
                } label: {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("I want to collect")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Button {
                    onSelect(.donor)
                } label: {
                    HStack {
                        Image(systemName: "house")
                        Text("I want to donate")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
            .interactiveDismissDisabled(true)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
        .environmentObject(LocationService())
}
