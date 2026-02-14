//
//  MainTabView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var userType: UserType = .collector // Toggle this for demo
    
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
            ProfileView(userType: userType)
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

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    MainTabView()
}
