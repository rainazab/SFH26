//
//  MockDataService.swift
//  Bottle
//
//  Multi-user demo state manager (hackathon mode)
//

import Foundation
import SwiftUI
import Combine
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MockDataService: ObservableObject {
    static let shared = MockDataService()
    
    enum DemoMode {
        case collector
        case donor
    }
    
    @Published var availableJobs: [BottleJob] = []
    @Published var claimedJobs: [BottleJob] = []
    @Published var completedJobs: [PickupHistory] = []
    @Published var currentUser: UserProfile
    @Published var impactStats: ImpactStats
    @Published var allUsers: [UserProfile]
    
    @Published var hasActiveJob: Bool = false
    @Published var canClaimNewJob: Bool = true
    @Published var demoMode: DemoMode = .collector
    
    @Published var currentLocation: CLLocationCoordinate2D?
    
    private enum StorageKeys {
        static let availableJobs = "bottlr.availableJobs"
        static let claimedJobs = "bottlr.claimedJobs"
        static let completedJobs = "bottlr.completedJobs"
        static let currentUser = "bottlr.currentUser"
        static let impactStats = "bottlr.impactStats"
        static let allUsers = "bottlr.allUsers"
    }
    
    private var simulationTimer: Timer?
    
    private init() {
        let initialUsers = [
            UserProfile.mockCollector,
            UserProfile(
                id: "collector2",
                name: "Sarah K.",
                email: "sarah@example.com",
                type: .collector,
                rating: 4.9,
                totalBottles: 2100,
                totalEarnings: 210.0,
                joinDate: Date().addingTimeInterval(-60 * 60 * 24 * 60),
                badges: []
            ),
            UserProfile.mockDonor
        ]
        self.allUsers = initialUsers
        self.currentUser = initialUsers[0]
        self.availableJobs = BottleJob.mockJobs
        self.claimedJobs = []
        self.completedJobs = PickupHistory.mockHistory
        self.impactStats = ImpactStats.mockStats
        self.currentLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        loadPersistedState()
        updateJobDistances()
        startRealtimeSimulation()
    }
    
    // MARK: - Multi-user demo
    
    func switchUser(to index: Int) {
        guard index >= 0, index < allUsers.count else { return }
        currentUser = allUsers[index]
        demoMode = currentUser.type == .donor ? .donor : .collector
        hasActiveJob = !claimedJobs.contains(where: { $0.claimedBy == currentUser.id })
        canClaimNewJob = !hasActiveJob
        persistState()
    }

    func syncAuthenticatedUser(_ profile: UserProfile) {
        if let existingIndex = allUsers.firstIndex(where: { $0.id == profile.id }) {
            allUsers[existingIndex] = profile
        } else if let collectorIndex = allUsers.firstIndex(where: { $0.type == .collector }) {
            allUsers[collectorIndex] = profile
        } else {
            allUsers.insert(profile, at: 0)
        }
        currentUser = profile
        demoMode = profile.type == .donor ? .donor : .collector
        hasActiveJob = !claimedJobs.contains(where: { $0.claimedBy == currentUser.id })
        canClaimNewJob = !hasActiveJob
        persistState()
    }
    
    func resetDemo() {
        availableJobs = BottleJob.mockJobs
        claimedJobs = []
        completedJobs = PickupHistory.mockHistory
        impactStats = ImpactStats.mockStats
        hasActiveJob = false
        canClaimNewJob = true
        updateJobDistances()
        persistState()
    }
    
    // MARK: - Job locking and lifecycle
    
    func claimJob(_ job: BottleJob) async throws {
        guard currentUser.type == .collector else {
            throw AppError.validation("Only collectors can claim posts.")
        }
        guard canClaimNewJob else {
            throw AppError.validation("Complete your current pickup before claiming another post.")
        }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        guard let idx = availableJobs.firstIndex(where: { $0.id == job.id }) else { return }
        var updated = availableJobs.remove(at: idx)
        updated.status = .claimed
        updated.claimedBy = currentUser.id
        claimedJobs.insert(updated, at: 0)
        
        hasActiveJob = true
        canClaimNewJob = false
        HapticManager.shared.notification(.success)
        persistState()
    }
    
    func releaseJob(_ job: BottleJob) {
        guard let idx = claimedJobs.firstIndex(where: { $0.id == job.id }) else { return }
        var updated = claimedJobs.remove(at: idx)
        updated.status = .available
        updated.claimedBy = nil
        availableJobs.insert(updated, at: 0)
        
        hasActiveJob = false
        canClaimNewJob = true
        updateJobDistances()
        persistState()
    }
    
    func completeJob(
        _ job: BottleJob,
        bottleCount: Int,
        aiVerified: Bool
    ) async throws {
        guard let idx = claimedJobs.firstIndex(where: { $0.id == job.id }) else {
            throw AppError.notFound
        }
        
        try await Task.sleep(nanoseconds: 700_000_000)
        
        _ = claimedJobs.remove(at: idx)
        
        // update user stats
        currentUser.totalBottles += bottleCount
        currentUser.totalEarnings += job.payout
        
        if let userIdx = allUsers.firstIndex(where: { $0.id == currentUser.id }) {
            allUsers[userIdx] = currentUser
        }
        
        let history = PickupHistory(
            id: UUID().uuidString,
            jobTitle: job.title,
            date: Date(),
            bottleCount: bottleCount,
            earnings: job.payout,
            rating: 5.0,
            review: ""
        )
        completedJobs.insert(history, at: 0)
        
        impactStats.totalBottles += bottleCount
        impactStats.totalEarnings += job.payout
        impactStats.co2Saved += Double(bottleCount) * 0.045
        impactStats.treesEquivalent = Int(impactStats.co2Saved / 20.0)
        
        hasActiveJob = false
        canClaimNewJob = true
        HapticManager.shared.notification(.success)
        persistState()
    }
    
    // MARK: - Donor actions
    
    func createDonorJob(
        title: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        bottleCount: Int,
        schedule: String,
        notes: String,
        isRecurring: Bool,
        tier: JobTier
    ) async throws {
        guard currentUser.type == .donor else {
            throw AppError.validation("Only donors can create posts.")
        }
        
        try await Task.sleep(nanoseconds: 400_000_000)
        
        let newJob = BottleJob(
            id: UUID().uuidString,
            donorId: currentUser.id,
            title: title,
            location: GeoLocation(coordinate: coordinate),
            address: address,
            bottleCount: bottleCount,
            payout: Double(bottleCount) * 0.1,
            tier: tier,
            status: .available,
            schedule: schedule,
            notes: notes,
            donorRating: currentUser.rating,
            isRecurring: isRecurring,
            availableTime: "Available now",
            claimedBy: nil,
            createdAt: Date(),
            distance: nil
        )
        availableJobs.insert(newJob, at: 0)
        updateJobDistances()
        persistState()
    }

    func updateDonorJob(
        postID: String,
        title: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        bottleCount: Int,
        schedule: String,
        notes: String,
        isRecurring: Bool,
        tier: JobTier,
        bottlePhotoBase64: String?,
        locationPhotoBase64: String?
    ) async throws {
        guard currentUser.type == .donor else {
            throw AppError.validation("Only donors can edit posts.")
        }
        guard let idx = availableJobs.firstIndex(where: { $0.id == postID && $0.donorId == currentUser.id }) else {
            throw AppError.notFound
        }
        let updated = availableJobs[idx]
        guard updated.claimedBy == nil && (updated.status == .available || updated.status == .posted) else {
            throw AppError.validation("This post can no longer be edited.")
        }
        let replacement = BottleJob(
            id: updated.id,
            donorId: updated.donorId,
            title: title,
            location: GeoLocation(coordinate: coordinate),
            address: address,
            bottleCount: bottleCount,
            payout: Double(bottleCount) * 0.1,
            demandMultiplier: updated.demandMultiplier,
            tier: tier,
            status: updated.status,
            schedule: schedule,
            notes: notes,
            donorRating: updated.donorRating,
            isRecurring: isRecurring,
            availableTime: schedule,
            claimedBy: updated.claimedBy,
            createdAt: updated.createdAt,
            distance: updated.distance,
            bottlePhotoBase64: bottlePhotoBase64,
            locationPhotoBase64: locationPhotoBase64,
            expiresAt: updated.expiresAt,
            aiConfidence: updated.aiConfidence,
            materialBreakdown: updated.materialBreakdown,
            pickedInDaytime: updated.pickedInDaytime,
            collectorRatingByHost: updated.collectorRatingByHost
        )

        availableJobs[idx] = replacement
        updateJobDistances()
        persistState()
    }

    func deleteDonorJob(postID: String) async throws {
        guard currentUser.type == .donor else {
            throw AppError.validation("Only donors can delete posts.")
        }
        guard let idx = availableJobs.firstIndex(where: { $0.id == postID && $0.donorId == currentUser.id }) else {
            throw AppError.notFound
        }
        let post = availableJobs[idx]
        guard post.claimedBy == nil && (post.status == .available || post.status == .posted) else {
            throw AppError.validation("This post can no longer be deleted.")
        }
        availableJobs.remove(at: idx)
        updateJobDistances()
        persistState()
    }
    
    // MARK: - Location
    
    func updateJobDistances() {
        guard let userLocation = currentLocation else { return }
        let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        availableJobs = availableJobs.map { job in
            var updated = job
            let jobLoc = CLLocation(latitude: job.location.latitude, longitude: job.location.longitude)
            updated.distance = user.distance(from: jobLoc) / 1609.34
            return updated
        }.sorted { ($0.distance ?? 999) < ($1.distance ?? 999) }
    }

    func updateLocation(_ coordinate: CLLocationCoordinate2D) {
        currentLocation = coordinate
        updateJobDistances()
    }
    
    func startNavigation(to job: BottleJob) {
        #if canImport(UIKit)
        let lat = job.location.latitude
        let lon = job.location.longitude
        if let url = URL(string: "maps://?daddr=\(lat),\(lon)&dirflg=d"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    func openNearbyRecyclingCenters() {
        #if canImport(UIKit)
        let lat = currentLocation?.latitude ?? 37.7749
        let lon = currentLocation?.longitude ?? -122.4194
        if let url = URL(string: "maps://?q=recycling+center&sll=\(lat),\(lon)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    // MARK: - Persistence
    
    private func persistState() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(availableJobs) {
            UserDefaults.standard.set(data, forKey: StorageKeys.availableJobs)
        }
        if let data = try? encoder.encode(claimedJobs) {
            UserDefaults.standard.set(data, forKey: StorageKeys.claimedJobs)
        }
        if let data = try? encoder.encode(completedJobs) {
            UserDefaults.standard.set(data, forKey: StorageKeys.completedJobs)
        }
        if let data = try? encoder.encode(currentUser) {
            UserDefaults.standard.set(data, forKey: StorageKeys.currentUser)
        }
        if let data = try? encoder.encode(impactStats) {
            UserDefaults.standard.set(data, forKey: StorageKeys.impactStats)
        }
        if let data = try? encoder.encode(allUsers) {
            UserDefaults.standard.set(data, forKey: StorageKeys.allUsers)
        }
    }
    
    private func loadPersistedState() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: StorageKeys.availableJobs),
           let decoded = try? decoder.decode([BottleJob].self, from: data) {
            availableJobs = decoded
        }
        if let data = UserDefaults.standard.data(forKey: StorageKeys.claimedJobs),
           let decoded = try? decoder.decode([BottleJob].self, from: data) {
            claimedJobs = decoded
        }
        if let data = UserDefaults.standard.data(forKey: StorageKeys.completedJobs),
           let decoded = try? decoder.decode([PickupHistory].self, from: data) {
            completedJobs = decoded
        }
        if let data = UserDefaults.standard.data(forKey: StorageKeys.currentUser),
           let decoded = try? decoder.decode(UserProfile.self, from: data) {
            currentUser = decoded
        }
        if let data = UserDefaults.standard.data(forKey: StorageKeys.impactStats),
           let decoded = try? decoder.decode(ImpactStats.self, from: data) {
            impactStats = decoded
        }
        if let data = UserDefaults.standard.data(forKey: StorageKeys.allUsers),
           let decoded = try? decoder.decode([UserProfile].self, from: data),
           !decoded.isEmpty {
            allUsers = decoded
        }
    }
    
    // MARK: - Realtime Simulation
    
    private func startRealtimeSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 18, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.generateRandomJob()
            }
        }
    }
    
    private func generateRandomJob() {
        let titles = ["Mission District Cafe", "SOMA Office Lobby", "Berkeley Student House", "Oakland Corner Store"]
        let addresses = ["450 Valencia St, SF", "2nd St, SF", "Shattuck Ave, Berkeley", "Grand Ave, Oakland"]
        let coords = [
            CLLocationCoordinate2D(latitude: 37.7599, longitude: -122.4148),
            CLLocationCoordinate2D(latitude: 37.7868, longitude: -122.3998),
            CLLocationCoordinate2D(latitude: 37.8715, longitude: -122.2730),
            CLLocationCoordinate2D(latitude: 37.8123, longitude: -122.2442)
        ]
        
        guard Bool.random() else { return }
        let idx = Int.random(in: 0..<titles.count)
        let bottleCount = Int.random(in: 20...180)
        let newJob = BottleJob(
            id: UUID().uuidString,
            donorId: "live_donor_\(idx)",
            title: titles[idx],
            location: GeoLocation(coordinate: coords[idx]),
            address: addresses[idx],
            bottleCount: bottleCount,
            payout: Double(bottleCount) * 0.1,
            tier: [.residential, .bulk, .commercial].randomElement() ?? .residential,
            status: .available,
            schedule: "Today",
            notes: "Auto-posted live listing",
            donorRating: Double.random(in: 4.6...5.0),
            isRecurring: false,
            availableTime: "Posted just now",
            claimedBy: nil,
            createdAt: Date(),
            distance: nil
        )
        availableJobs.insert(newJob, at: 0)
        updateJobDistances()
        persistState()
    }
}
