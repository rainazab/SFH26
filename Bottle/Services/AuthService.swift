//
//  AuthService.swift
//  Bottle
//
//  Firebase Authentication Service (Mock Profile Storage for Hackathon)
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
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
                    self?.createMockProfile(for: user)
                    self?.isAuthenticated = true
                } else {
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
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            createMockProfile(for: result.user, name: name, type: userType)
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
            createMockProfile(for: result.user)
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
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AppError.authentication("Missing Google Client ID")
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                throw AppError.authentication("Failed to get ID token")
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            createMockProfile(
                for: authResult.user,
                name: user.profile?.name ?? "User",
                type: .collector
            )
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
    
    // MARK: - Mock Profile (Hackathon Demo)
    private func createMockProfile(for user: User, name: String? = nil, type: UserType = .collector) {
        currentUser = UserProfile(
            id: user.uid,
            name: name ?? user.displayName ?? user.email?.components(separatedBy: "@").first ?? "User",
            email: user.email ?? "",
            type: type,
            rating: 4.8,
            totalBottles: 3420,
            totalEarnings: 342.0,
            joinDate: Date().addingTimeInterval(-60*60*24*90),
            badges: Badge.mockBadges
        )
    }
}
