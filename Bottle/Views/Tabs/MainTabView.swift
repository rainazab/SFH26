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
    @EnvironmentObject var dataService: DataService
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
    @EnvironmentObject var dataService: DataService
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
        .onReceive(NotificationCenter.default.publisher(for: AppNotificationService.openCollectionPointNotification)) { _ in
            selectedTab = 0
        }
    }
}

struct CollectorTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var selectedTab = 0
    let locationService: LocationService

    var body: some View {
        TabView(selection: $selectedTab) {
            CollectorJobsView()
                .environmentObject(locationService)
                .tabItem { Label("Posts", systemImage: "briefcase.fill") }
                .tag(0)

            ActivityView()
                .tabItem { Label("Pickups", systemImage: "clock.fill") }
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
        .onReceive(NotificationCenter.default.publisher(for: AppNotificationService.openCollectionPointNotification)) { notification in
            selectedTab = 0
            if let postId = notification.userInfo?[AppNotificationService.postIDUserInfoKey] as? String {
                dataService.queueCollectionPointOpen(postId: postId)
            }
        }
    }
}

struct CollectorJobsView: View {
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var locationService: LocationService
    @State private var mode: JobsMode = .map
    @AppStorage("bottlr.firstRunTip.collector") private var showCollectorTip = true

    enum JobsMode: String, CaseIterable {
        case map = "Map"
        case list = "List"
    }

    var body: some View {
        Group {
            if mode == .map {
                ZStack(alignment: .top) {
                    MapView(onShowList: {
                        mode = .list
                    })
                    .environmentObject(locationService)

                    VStack(spacing: 8) {
                        if showCollectorTip {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.brandGreen)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Quick guide")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Browse posts on the map or list, claim one, then verify pickup with a photo.")
                                        .font(.subheadline)
                                }
                                Spacer()
                                Button {
                                    showCollectorTip = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }

                        Picker("View", selection: $mode) {
                            ForEach(JobsMode.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.16), radius: 10, y: 4)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                }
            } else {
                VStack(spacing: 0) {
                    if showCollectorTip {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.brandGreen)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quick guide")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Browse posts on the map or list, claim one, then verify pickup with a photo.")
                                    .font(.subheadline)
                            }
                            Spacer()
                            Button {
                                showCollectorTip = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    Picker("View", selection: $mode) {
                        ForEach(JobsMode.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    JobListView()
                        .environmentObject(locationService)
                }
            }
        }
        .onAppear {
            if let pending = AppNotificationService.shared.consumePendingCollectionPointRoute() {
                dataService.queueCollectionPointOpen(postId: pending)
                mode = .map
            }
        }
        .onChange(of: dataService.pendingCollectionPointID) { _, newValue in
            if newValue != nil {
                mode = .map
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
                        Text("I want to host")
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
        .environmentObject(DataService.shared)
}
