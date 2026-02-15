//
//  BottleApp.swift
//  Bottle
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

// MARK: - App Delegate for Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Required for Firebase Phone Auth verification (silent APNs flow).
        application.registerForRemoteNotifications()
        
        // Validate API keys on launch
        let missingKeys = Config.validateConfiguration()
        if !missingKeys.isEmpty {
            print("⚠️ Missing API keys: \(missingKeys.joined(separator: ", "))")
            print("📝 Please set these in your .env file")
        }
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ APNs registration failed: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
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
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color.brandGreen, Color.brandGreenLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}
