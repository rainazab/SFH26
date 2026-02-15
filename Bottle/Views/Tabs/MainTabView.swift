//
//  MainTabView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    
    private var userType: UserType {
        authService.currentUser?.type ?? .collector
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
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
