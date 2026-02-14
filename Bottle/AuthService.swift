//
//  AuthService.swift
//  Bottle
//
//  Firebase Authentication Service
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import CryptoKit

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private let mongoService = MongoDBService()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        // Configure Firebase on init
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        setupAuthListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    // User signed in - fetch profile
                    await self?.fetchUserProfile(userId: user.uid)
                    self?.isAuthenticated = true
                } else {
                    // User signed out
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(
        email: String,
        password: String,
        name: String,
        userType: UserType
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create profile in MongoDB
            let profile = UserProfile(
                id: result.user.uid,
                name: name,
                email: email,
                type: userType,
                rating: 0.0,
                totalBottles: 0,
                totalEarnings: 0.0,
                joinDate: Date(),
                badges: []
            )
            
            _ = try await mongoService.createUser(profile)
            
            // Initialize impact stats
            try await mongoService.updateImpactStats(
                userId: result.user.uid,
                bottlesAdded: 0,
                co2Added: 0
            )
            
            await fetchUserProfile(userId: result.user.uid)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await fetchUserProfile(userId: result.user.uid)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get the client ID from GoogleService-Info.plist
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AppError.authentication("Missing Google Client ID")
            }
            
            // Configure Google Sign In
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Start the sign in flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                throw AppError.authentication("Failed to get ID token")
            }
            
            let accessToken = user.accessToken.tokenString
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Check if user exists in MongoDB
            let existingUser = try? await mongoService.fetchUser(userId: authResult.user.uid)
            
            if existingUser == nil {
                // New user - create profile in MongoDB
                let profile = UserProfile(
                    id: authResult.user.uid,
                    name: user.profile?.name ?? "User",
                    email: user.profile?.email ?? "",
                    type: .collector, // Default to collector, can be changed later
                    rating: 0.0,
                    totalBottles: 0,
                    totalEarnings: 0.0,
                    joinDate: Date(),
                    badges: []
                )
                
                _ = try await mongoService.createUser(profile)
                
                // Initialize impact stats
                try await mongoService.updateImpactStats(
                    userId: authResult.user.uid,
                    bottlesAdded: 0,
                    co2Added: 0
                )
            }
            
            await fetchUserProfile(userId: authResult.user.uid)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            throw AppError.authentication(error.localizedDescription)
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AppError.authentication(error.localizedDescription)
        }
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AppError.unauthorized
        }
        
        do {
            try await user.delete()
            currentUser = nil
            isAuthenticated = false
        } catch {
            throw AppError.authentication(error.localizedDescription)
        }
    }
    
    // MARK: - Profile Management
    
    private func fetchUserProfile(userId: String) async {
        do {
            currentUser = try await mongoService.fetchUser(userId: userId)
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }
    
    func updateFCMToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AppError.unauthorized
        }
        
        // Update FCM token in MongoDB
        // TODO: Implement updateOne for user's fcm_token field
    }
}
