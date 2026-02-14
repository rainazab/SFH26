//
//  BottleApp.swift
//  Bottle
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import FirebaseCore

// MARK: - App Delegate for Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Validate API keys on launch
        let missingKeys = Config.validateConfiguration()
        if !missingKeys.isEmpty {
            print("⚠️ Missing API keys: \(missingKeys.joined(separator: ", "))")
            print("📝 Please set these in your .env file")
        }
        
        return true
    }
}

// MARK: - Main App

@main
struct BottleApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authService = AuthService()
    @StateObject private var locationService = LocationService()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    // Loading state
                    LoadingView()
                } else if !hasSeenWelcome {
                    // Onboarding
                    WelcomeView(showWelcome: .constant(true))
                        .onAppear {
                            hasSeenWelcome = true
                        }
                } else if authService.isAuthenticated {
                    // Main app
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(locationService)
                } else {
                    // Login
                    LoginView()
                        .environmentObject(authService)
                }
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "waterbottle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.brandGreen)
                
                Text("BOTTLE")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.brandGreen)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandGreen))
            }
        }
    }
}
