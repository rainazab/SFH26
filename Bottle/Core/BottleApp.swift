//
//  BottleApp.swift
//  Bottle
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications

// MARK: - App Delegate for Firebase

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Required for Firebase Phone Auth verification (silent APNs flow).
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        
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

    // Required for Firebase Phone Auth reCAPTCHA fallback flow.
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let postId = response.notification.request.content.userInfo[AppNotificationService.postIDUserInfoKey] as? String {
            AppNotificationService.shared.routeToCollectionPoint(postId: postId)
        }
        completionHandler()
    }
}

// MARK: - Main App

@main
struct BottleApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authService = AuthService()
    @StateObject private var locationService = LocationService()
    @StateObject private var dataService = DataService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    // Loading state
                    LoadingView()
                } else if !authService.isAuthenticated {
                    // Login
                    LoginView()
                        .environmentObject(authService)
                } else if authService.needsRoleSelection {
                    OnboardingView()
                        .environmentObject(authService)
                } else if authService.isAuthenticated {
                    // Main app
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(locationService)
                }
            }
            .environmentObject(dataService)
            .onAppear {
                dataService.syncAuthenticatedUser(authService.currentUser)
            }
            .onReceive(authService.$currentUser) { user in
                dataService.syncAuthenticatedUser(user)
            }
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                if !isAuthenticated {
                    dataService.syncAuthenticatedUser(nil)
                }
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.brandWhite, Color.brandBlueSurface, Color.brandBlueDark]
                        : [Color(hex: "C7E7FD"), Color(hex: "66C2FF"), Color(hex: "3694E8")],
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
