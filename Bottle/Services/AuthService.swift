//
//  AuthService.swift
//  Bottle
//
//  Firebase authentication + persisted user role/profile in Firestore
//

import Foundation
import Combine
import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var needsRoleSelection = false
    @Published var shouldPromptRoleSelection = false

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var verificationID: String?
    private let db = Firestore.firestore()

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
                guard let self else { return }
                if let user {
                    await self.loadPersistedUser(for: user)
                } else {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.needsRoleSelection = false
                    self.isLoading = false
                }
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
        errorMessage = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let request = result.user.createProfileChangeRequest()
            request.displayName = name
            try? await request.commitChanges()
            try await persistUserProfile(name: name, userType: userType)
        } catch {
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        errorMessage = nil

        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
    }

    // MARK: - Phone Auth
    func sendPhoneVerification(to phoneNumber: String) async throws {
        errorMessage = nil

        do {
            verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
        } catch {
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
    }

    func signInWithPhoneCode(_ code: String) async throws {
        guard let verificationID else {
            throw AppError.authentication("Request a verification code first")
        }

        errorMessage = nil

        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: code
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            await loadPersistedUser(for: authResult.user)
        } catch {
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
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

            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            let nsError = error as NSError
            if nsError.domain.contains("GIDSignIn") && nsError.code == -5 {
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
            throw AppError.authentication(error.localizedDescription)
        }
    }

    func setCurrentUserType(_ type: UserType) {
        Task {
            do {
                try await persistUserProfile(name: currentUser?.name ?? "User", userType: type)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func completeOnboarding(name: String, userType: UserType) {
        Task {
            do {
                try await persistUserProfile(name: name, userType: userType)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateProfilePhoto(_ image: UIImage) async throws {
        do {
            try await uploadProfilePhoto(image)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Sign Out
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
            needsRoleSelection = false
            verificationID = nil
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
            needsRoleSelection = false
        } catch {
            throw AppError.authentication(error.localizedDescription)
        }
    }

    // MARK: - Firestore Profile
    private func loadPersistedUser(for firebaseUser: User) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("users").document(firebaseUser.uid).getDocument()
            guard let data = snapshot.data(),
                  let roleRaw = (data["role"] as? String) ?? (data["type"] as? String),
                  let role = UserType(rawValue: roleRaw) else {
                currentUser = provisionalProfile(for: firebaseUser)
                isAuthenticated = true
                needsRoleSelection = true
                shouldPromptRoleSelection = false
                return
            }

            let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = (data["email"] as? String) ?? firebaseUser.email ?? ""
            let totalEarnings = (data["totalEarnings"] as? Double) ?? (data["totalEarnings"] as? NSNumber)?.doubleValue ?? 0
            let totalBottles = (data["totalBottlesDiverted"] as? Int)
                ?? (data["totalBottlesDiverted"] as? NSNumber)?.intValue
                ?? (data["totalBottles"] as? Int)
                ?? (data["totalBottles"] as? NSNumber)?.intValue
                ?? 0
            let joinDate = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let persistedRating = (data["rating"] as? Double) ?? (data["rating"] as? NSNumber)?.doubleValue ?? 0
            let profilePhotoReference = (data["profilePhotoPath"] as? String)
                ?? (data["profilePhotoUrl"] as? String)
                ?? (data["profilePhotoBase64"] as? String)

            let profile = UserProfile(
                id: firebaseUser.uid,
                name: (name?.isEmpty == false ? name! : (firebaseUser.displayName ?? "User")),
                email: email,
                type: role,
                rating: persistedRating,
                totalBottles: totalBottles,
                totalEarnings: totalEarnings,
                joinDate: joinDate,
                badges: Badge.mockBadges,
                profilePhotoUrl: profilePhotoReference
            )
            currentUser = profile
            MockDataService.shared.syncAuthenticatedUser(profile)
            isAuthenticated = true
            needsRoleSelection = false
            shouldPromptRoleSelection = false
        } catch {
            errorMessage = error.localizedDescription
            currentUser = provisionalProfile(for: firebaseUser)
            isAuthenticated = true
            needsRoleSelection = true
            shouldPromptRoleSelection = false
        }
    }

    private func persistUserProfile(name: String, userType: UserType) async throws {
        guard let firebaseUser = Auth.auth().currentUser else { throw AppError.unauthorized }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = provisionalProfile(for: firebaseUser)
        let existing = currentUser ?? fallback

        let persisted = UserProfile(
            id: existing.id,
            name: trimmedName.isEmpty ? existing.name : trimmedName,
            email: existing.email.isEmpty ? (firebaseUser.email ?? "") : existing.email,
            type: userType,
            rating: existing.rating,
            totalBottles: existing.totalBottles,
            totalEarnings: existing.totalEarnings,
            joinDate: existing.joinDate,
            badges: existing.badges,
            fcmToken: existing.fcmToken,
            profilePhotoUrl: existing.profilePhotoUrl
        )

        let payload: [String: Any] = [
            "id": persisted.id,
            "email": persisted.email,
            "name": persisted.name,
            "role": persisted.type.rawValue,
            "type": persisted.type.rawValue,
            "totalEarnings": persisted.totalEarnings,
            "totalBottlesDiverted": persisted.totalBottles,
            "totalBottles": persisted.totalBottles,
            "profilePhotoBase64": persisted.profilePhotoUrl as Any,
            "profilePhotoPath": persisted.profilePhotoUrl as Any,
            "profilePhotoUrl": persisted.profilePhotoUrl as Any,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": Timestamp(date: persisted.joinDate)
        ]

        try await db.collection("users").document(firebaseUser.uid).setData(payload, merge: true)
        currentUser = persisted
        MockDataService.shared.syncAuthenticatedUser(persisted)
        isAuthenticated = true
        needsRoleSelection = false
        shouldPromptRoleSelection = false
    }

    private func provisionalProfile(for user: User, type: UserType = .collector) -> UserProfile {
        UserProfile(
            id: user.uid,
            name: user.displayName ?? user.email?.components(separatedBy: "@").first ?? "User",
            email: user.email ?? "",
            type: type,
            rating: 0,
            totalBottles: 0,
            totalEarnings: 0,
            joinDate: Date(),
            badges: Badge.mockBadges
        )
    }

    private func uploadProfilePhoto(_ image: UIImage) async throws {
        guard let firebaseUser = Auth.auth().currentUser else { throw AppError.unauthorized }
        guard let data = resizedProfileImageData(from: image) else {
            throw AppError.validation("Could not process profile image.")
        }
        let photoReference = try saveProfilePhotoToDocuments(data: data, userId: firebaseUser.uid)
        let thumbnailBase64 = data.base64EncodedString()
        try await db.collection("users").document(firebaseUser.uid).setData([
            "profilePhotoBase64": thumbnailBase64,
            "profilePhotoPath": photoReference,
            "profilePhotoUrl": photoReference,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        if var current = currentUser {
            current = UserProfile(
                id: current.id,
                name: current.name,
                email: current.email,
                type: current.type,
                rating: current.rating,
                totalBottles: current.totalBottles,
                totalEarnings: current.totalEarnings,
                joinDate: current.joinDate,
                badges: current.badges,
                fcmToken: current.fcmToken,
                profilePhotoUrl: photoReference
            )
            currentUser = current
            MockDataService.shared.syncAuthenticatedUser(current)
        }
    }

    private func resizedProfileImageData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 640
        let originalSize = image.size
        let scale = min(1.0, maxDimension / max(originalSize.width, originalSize.height))
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.72)
    }

    private func saveProfilePhotoToDocuments(data: Data, userId: String) throws -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let docs else {
            throw AppError.validation("Could not access local storage for profile photo.")
        }
        let profilesDir = docs.appendingPathComponent("ProfilePhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: profilesDir.path) {
            try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true, attributes: nil)
        }
        let fileURL = profilesDir.appendingPathComponent("\(userId).jpg")
        try data.write(to: fileURL, options: .atomic)
        return fileURL.absoluteString
    }
}
