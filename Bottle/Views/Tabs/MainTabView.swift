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
    @State private var showLocationPrompt = false
    
    private var userType: UserType {
        dataService.currentUser?.type ?? .collector
    }
    
    var body: some View {
        Group {
            if userType == .donor {
                DonorTabView(locationService: locationService)
                    .environmentObject(authService)
            } else {
                CollectorTabView(locationService: locationService)
                    .environmentObject(authService)
            }
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
            Text("bottlr uses your location to show nearby posts and sort pickups around you.")
        }
    }
}

struct DonorTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var dataService = DataService.shared
    @State private var selectedTab = 0
    let locationService: LocationService

    var body: some View {
        TabView(selection: $selectedTab) {
            DonorHomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ActivityView()
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(1)

            DonorMapView()
                .environmentObject(locationService)
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(2)

            ProfileView()
                .environmentObject(authService)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(3)
        }
        .accentColor(.brandGreen)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.shared.selection()
        }
    }
}

struct CollectorTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    let locationService: LocationService

    var body: some View {
        TabView(selection: $selectedTab) {
            CollectorJobsView()
                .environmentObject(locationService)
                .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                .tag(0)

            ActivityView()
                .tabItem { Label("Active", systemImage: "clock.fill") }
                .tag(1)

            ProfileView()
                .environmentObject(authService)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
        .accentColor(.brandGreen)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.shared.selection()
        }
    }
}

struct CollectorJobsView: View {
    @EnvironmentObject var locationService: LocationService
    @State private var mode: JobsMode = .map

    enum JobsMode: String, CaseIterable {
        case map = "Map"
        case list = "List"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $mode) {
                ForEach(JobsMode.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            if mode == .map {
                MapView()
                    .environmentObject(locationService)
            } else {
                JobListView()
                    .environmentObject(locationService)
            }
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
