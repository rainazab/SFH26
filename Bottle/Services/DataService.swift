//
//  DataService.swift
//  bottlr
//
//  Shared data layer with Firestore primary + local fallback.
//

import Foundation
import Combine
import CoreLocation
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class DataService: ObservableObject, DataServiceProtocol {
    static let shared = DataService()

    @Published var availableJobs: [BottleJob] = []
    @Published var myClaimedJobs: [BottleJob] = []
    @Published var myPostedJobs: [BottleJob] = []
    @Published var completedJobs: [PickupHistory] = []
    @Published var currentUser: UserProfile?
    @Published var impactStats: ImpactStats = .mockStats
    @Published var walletTransactions: [WalletTransaction] = []
    @Published var leaderboardUsers: [UserProfile] = []
    @Published var activityTimeline: [ActivityEvent] = []
    @Published var cityBottlesToday: Int = 0
    @Published var cityCO2Today: Double = 0
    @Published var backendStatus: String = "local"
    @Published var lastSyncError: String?

    var hasActiveJob: Bool { !myClaimedJobs.isEmpty }
    var canClaimNewJob: Bool { !hasActiveJob }

    private let appState = MockDataService.shared
    private var cancellables: Set<AnyCancellable> = []
    private var userCoordinate: CLLocationCoordinate2D?
    private var isFirestoreEnabled = false

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    private var jobsListener: ListenerRegistration?
    private var pickupsListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?
    private var cityImpactListener: ListenerRegistration?
    #endif

    private enum StorageKeys {
        static let walletTransactions = "bottlr.wallet.transactions"
    }

    private init() {
        loadPersistedWallet()
        bindCurrentUser()
        configureBackend()
    }

    private func bindCurrentUser() {
        appState.$currentUser
            .sink { [weak self] user in
                guard let self else { return }
                self.currentUser = user
                if self.isFirestoreEnabled {
                    self.refreshDerivedCollections()
                }
                #if canImport(FirebaseFirestore)
                self.observePickups()
                #endif
            }
            .store(in: &cancellables)
    }

    private func configureBackend() {
        #if canImport(FirebaseFirestore)
        if AppConfig.useMockData {
            isFirestoreEnabled = false
            backendStatus = "mock"
            bindFallbackState()
        } else {
            isFirestoreEnabled = true
            backendStatus = "firestore"
            observeJobs()
            observePickups()
            observeLeaderboard()
            observeCityImpact()
        }
        #else
        isFirestoreEnabled = false
        backendStatus = "local"
        bindFallbackState()
        #endif
    }

    func refreshBackendMode() {
        #if canImport(FirebaseFirestore)
        jobsListener?.remove()
        pickupsListener?.remove()
        usersListener?.remove()
        cityImpactListener?.remove()
        jobsListener = nil
        pickupsListener = nil
        usersListener = nil
        cityImpactListener = nil
        cancellables.removeAll()
        bindCurrentUser()
        #endif
        configureBackend()
    }

    private func bindFallbackState() {
        appState.$availableJobs.assign(to: &$availableJobs)
        appState.$claimedJobs.assign(to: &$myClaimedJobs)
        appState.$completedJobs.assign(to: &$completedJobs)
        appState.$impactStats.assign(to: &$impactStats)

        appState.$availableJobs
            .combineLatest(appState.$currentUser)
            .map { jobs, user in jobs.filter { $0.donorId == user.id } }
            .assign(to: &$myPostedJobs)

        appState.$allUsers
            .map { users in
                users.sorted { $0.totalBottles > $1.totalBottles }
            }
            .assign(to: &$leaderboardUsers)

        appState.$completedJobs
            .sink { [weak self] history in
                self?.updateCityImpact(from: history)
            }
            .store(in: &cancellables)
    }

    private func refreshDerivedCollections() {
        guard let user = currentUser else { return }
        myPostedJobs = availableJobs.filter { $0.donorId == user.id }
        myClaimedJobs = availableJobs.filter { $0.claimedBy == user.id && $0.status == .claimed }
        recalculateImpactFromHistory()
        rebuildActivityTimeline()
    }

    private func recalculateImpactFromHistory() {
        let bottles = completedJobs.reduce(0) { $0 + $1.bottleCount }
        let transactionValue = walletTransactions.reduce(0.0) { $0 + $1.amount }
        let value = transactionValue > 0 ? transactionValue : completedJobs.reduce(0.0) { $0 + $1.earnings }
        let co2 = ClimateImpactCalculator.co2Saved(bottles: bottles)
        impactStats.totalBottles = bottles
        impactStats.totalEarnings = value
        impactStats.co2Saved = co2
        impactStats.treesEquivalent = Int(ClimateImpactCalculator.treesEquivalent(co2Kg: co2))
    }

    private func rebuildActivityTimeline() {
        var events: [ActivityEvent] = []

        events += completedJobs.map { pickup in
            ActivityEvent(
                id: "pickup-\(pickup.id)",
                type: .pickupCompleted,
                title: "Completed \(pickup.jobTitle)",
                amount: pickup.earnings,
                bottles: pickup.bottleCount,
                date: pickup.date
            )
        }

        events += walletTransactions.map { tx in
            ActivityEvent(
                id: "earn-\(tx.id)",
                type: .earningsAdded,
                title: tx.title,
                amount: tx.amount,
                bottles: tx.bottleCount,
                date: tx.date
            )
        }

        activityTimeline = events.sorted { $0.date > $1.date }
    }

    private func updateCityImpact(from pickups: [PickupHistory]) {
        let today = pickups.filter { Calendar.current.isDateInToday($0.date) }
        cityBottlesToday = today.reduce(0) { $0 + $1.bottleCount }
        cityCO2Today = ClimateImpactCalculator.co2Saved(bottles: cityBottlesToday)
    }

    func claimJob(_ job: BottleJob) async throws {
        guard let user = currentUser else { throw AppError.unauthorized }
        guard user.type == .collector else { throw AppError.validation("Only collectors can claim jobs.") }
        guard canClaimNewJob else { throw AppError.validation("Complete your current pickup before claiming another job.") }

        #if canImport(FirebaseFirestore)
        if isFirestoreEnabled {
            try await claimJobInFirestore(job, collectorId: user.id)
        } else {
            try await appState.claimJob(job)
        }
        #else
        try await appState.claimJob(job)
        #endif
    }

    func releaseJob(_ job: BottleJob) async {
        #if canImport(FirebaseFirestore)
        if isFirestoreEnabled {
            do {
                try await db.collection("jobs").document(job.id).updateData([
                    "status": "open",
                    "claimedBy": FieldValue.delete()
                ])
            } catch { }
        } else {
            appState.releaseJob(job)
        }
        #else
        appState.releaseJob(job)
        #endif
    }

    func completeJob(_ job: BottleJob, bottleCount: Int, aiVerified: Bool) async throws {
        guard let user = currentUser else { throw AppError.unauthorized }

        #if canImport(FirebaseFirestore)
        if isFirestoreEnabled {
            try await completeJobInFirestore(
                job,
                bottleCount: bottleCount,
                aiVerified: aiVerified,
                collectorId: user.id,
                proofPhotoBase64: nil
            )
        } else {
            try await appState.completeJob(job, bottleCount: bottleCount, aiVerified: aiVerified)
        }
        #else
        try await appState.completeJob(job, bottleCount: bottleCount, aiVerified: aiVerified)
        #endif

        let transaction = WalletTransaction(
            id: UUID().uuidString,
            date: Date(),
            title: "Verified pickup: \(job.title)",
            amount: job.estimatedValue,
            bottleCount: bottleCount
        )
        walletTransactions.insert(transaction, at: 0)
        persistWallet()
        rebuildActivityTimeline()
    }

    func completeJob(
        _ job: BottleJob,
        bottleCount: Int,
        aiVerified: Bool,
        proofPhotoBase64: String?
    ) async throws {
        guard let user = currentUser else { throw AppError.unauthorized }

        #if canImport(FirebaseFirestore)
        if isFirestoreEnabled {
            try await completeJobInFirestore(
                job,
                bottleCount: bottleCount,
                aiVerified: aiVerified,
                collectorId: user.id,
                proofPhotoBase64: proofPhotoBase64
            )
        } else {
            try await appState.completeJob(job, bottleCount: bottleCount, aiVerified: aiVerified)
        }
        #else
        try await appState.completeJob(job, bottleCount: bottleCount, aiVerified: aiVerified)
        #endif

        let transaction = WalletTransaction(
            id: UUID().uuidString,
            date: Date(),
            title: "Verified pickup: \(job.title)",
            amount: job.estimatedValue,
            bottleCount: bottleCount
        )
        walletTransactions.insert(transaction, at: 0)
        persistWallet()
        rebuildActivityTimeline()
    }

    func createJob(
        title: String,
        address: String,
        location: GeoLocation,
        bottleCount: Int,
        schedule: String,
        notes: String,
        isRecurring: Bool,
        tier: JobTier,
        availableTime: String,
        bottlePhotoBase64: String? = nil,
        locationPhotoBase64: String? = nil
    ) async throws {
        guard let user = currentUser else { throw AppError.unauthorized }
        guard user.type == .donor else { throw AppError.validation("Only donors can create jobs.") }

        #if canImport(FirebaseFirestore)
        if isFirestoreEnabled {
            try await createJobInFirestore(
                donorId: user.id,
                donorRating: user.rating,
                title: title,
                address: address,
                location: location,
                bottleCount: bottleCount,
                schedule: schedule,
                notes: notes,
                isRecurring: isRecurring,
                tier: tier,
                availableTime: availableTime,
                bottlePhotoBase64: bottlePhotoBase64,
                locationPhotoBase64: locationPhotoBase64
            )
        } else {
            try await appState.createDonorJob(
                title: title,
                address: address,
                coordinate: location.coordinate,
                bottleCount: bottleCount,
                schedule: schedule.isEmpty ? availableTime : schedule,
                notes: notes,
                isRecurring: isRecurring,
                tier: tier
            )
        }
        #else
        try await appState.createDonorJob(
            title: title,
            address: address,
            coordinate: location.coordinate,
            bottleCount: bottleCount,
            schedule: schedule.isEmpty ? availableTime : schedule,
            notes: notes,
            isRecurring: isRecurring,
            tier: tier
        )
        #endif
    }

    func updateJobDistances(from userLocation: CLLocationCoordinate2D) {
        userCoordinate = userLocation
        if isFirestoreEnabled {
            availableJobs = withDistances(availableJobs, from: userLocation)
            refreshDerivedCollections()
        } else {
            appState.updateLocation(userLocation)
        }
    }

    // MARK: - Protocol convenience methods

    func fetchUser(uid: String, completion: @escaping (UserProfile?) -> Void) {
        completion(currentUser?.id == uid ? currentUser : nil)
    }

    func createUser(_ user: UserProfile, completion: @escaping (Bool) -> Void) {
        currentUser = user
        MockDataService.shared.syncAuthenticatedUser(user)
        completion(true)
    }

    func fetchOpenJobs(completion: @escaping ([BottleJob]) -> Void) {
        completion(availableJobs.filter { $0.status == .available })
    }

    func fetchUserJobs(userId: String, completion: @escaping ([BottleJob]) -> Void) {
        completion(availableJobs.filter { $0.donorId == userId || $0.claimedBy == userId })
    }

    func acceptJob(jobId: String, collectorId: String) async throws {
        _ = collectorId
        guard let job = availableJobs.first(where: { $0.id == jobId }) else {
            throw AppError.notFound
        }
        try await claimJob(job)
    }

    func completeJob(job: BottleJob, bottleCount: Int, proofPhotoBase64: String?) async throws {
        try await completeJob(
            job,
            bottleCount: bottleCount,
            aiVerified: AppConfig.aiVerificationEnabled,
            proofPhotoBase64: proofPhotoBase64
        )
    }

    func injectHighValueDemoJob() async {
        guard let currentUser else { return }
        let coordinate = userCoordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        try? await createJob(
            title: "High-Value Eco Event",
            address: "Market St, San Francisco",
            location: GeoLocation(coordinate: coordinate),
            bottleCount: 420,
            schedule: "Today",
            notes: "Injected from demo control panel",
            isRecurring: false,
            tier: .commercial,
            availableTime: "Available now",
            bottlePhotoBase64: nil,
            locationPhotoBase64: nil
        )
        if currentUser.type == .collector {
            updateJobDistances(from: coordinate)
        }
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
        let lat = userCoordinate?.latitude ?? 37.7749
        let lon = userCoordinate?.longitude ?? -122.4194
        if let url = URL(string: "maps://?q=recycling+center&sll=\(lat),\(lon)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    func estimatedTravelTime(to destination: CLLocationCoordinate2D, from source: CLLocationCoordinate2D) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.transportType = .automobile
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first?.expectedTravelTime
        } catch {
            return nil
        }
    }

    private func withDistances(_ jobs: [BottleJob], from coordinate: CLLocationCoordinate2D) -> [BottleJob] {
        let user = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return jobs.map { job in
            var mutable = job
            let jobLoc = CLLocation(latitude: job.location.latitude, longitude: job.location.longitude)
            mutable.distance = user.distance(from: jobLoc) / 1609.34
            return mutable
        }
        .sorted { ($0.distance ?? 999) < ($1.distance ?? 999) }
    }

    private func persistWallet() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(walletTransactions) {
            UserDefaults.standard.set(data, forKey: StorageKeys.walletTransactions)
        }
    }

    private func loadPersistedWallet() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: StorageKeys.walletTransactions),
           let decoded = try? decoder.decode([WalletTransaction].self, from: data) {
            walletTransactions = decoded
        }
        rebuildActivityTimeline()
    }
}

#if canImport(FirebaseFirestore)
private extension DataService {
    func observeJobs() {
        jobsListener?.remove()
        jobsListener = db.collection("jobs").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastSyncError = "jobs sync failed: \(error.localizedDescription)"
                    return
                }
                guard let docs = snapshot?.documents else { return }
                var parsed = docs.compactMap(FirestoreJobRecord.init(document:)).map(\.job)
                if let userCoordinate = self.userCoordinate {
                    parsed = self.withDistances(parsed, from: userCoordinate)
                }
                self.availableJobs = parsed.filter { $0.status != .completed && $0.status != .cancelled }
                self.refreshDerivedCollections()
                self.lastSyncError = nil
            }
        }
    }

    func observePickups() {
        guard let userId = currentUser?.id else { return }
        pickupsListener?.remove()
        pickupsListener = db.collection("pickups")
            .whereField("collectorId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastSyncError = "pickups sync failed: \(error.localizedDescription)"
                        return
                    }
                    guard let docs = snapshot?.documents else { return }
                    self.completedJobs = docs
                        .compactMap(FirestorePickupRecord.init(document:))
                        .map(\.history)
                        .sorted { $0.date > $1.date }
                    self.recalculateImpactFromHistory()
                    self.lastSyncError = nil
                }
            }
    }

    func observeLeaderboard() {
        usersListener?.remove()
        usersListener = db.collection("users")
            .order(by: "totalBottlesDiverted", descending: true)
            .limit(to: 10)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, let docs = snapshot?.documents else { return }
                    self.leaderboardUsers = docs.compactMap(FirestoreUserRecord.init(document:)).map(\.user)
                }
            }
    }

    func observeCityImpact() {
        cityImpactListener?.remove()
        cityImpactListener = db.collection("pickups")
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, let docs = snapshot?.documents else { return }
                    let history = docs.compactMap(FirestorePickupRecord.init(document:)).map(\.history)
                    self.updateCityImpact(from: history)
                }
            }
    }

    func claimJobInFirestore(_ job: BottleJob, collectorId: String) async throws {
        let ref = db.collection("jobs").document(job.id)
        let snap = try await ref.getDocument()
        guard var record = FirestoreJobRecord(document: snap), record.status == .available else {
            throw AppError.validation("This job is no longer available.")
        }
        record.status = .claimed
        record.claimedBy = collectorId
        try await ref.setData(record.dictionary, merge: true)
    }

    func createJobInFirestore(
        donorId: String,
        donorRating: Double,
        title: String,
        address: String,
        location: GeoLocation,
        bottleCount: Int,
        schedule: String,
        notes: String,
        isRecurring: Bool,
        tier: JobTier,
        availableTime: String,
        bottlePhotoBase64: String?,
        locationPhotoBase64: String?
    ) async throws {
        let id = UUID().uuidString
        let payload = FirestoreJobRecord(
            id: id,
            donorId: donorId,
            title: title,
            latitude: location.latitude,
            longitude: location.longitude,
            address: address,
            bottleCount: bottleCount,
            payout: Double(bottleCount) * 0.10,
            demandMultiplier: demandMultiplier(for: tier, bottleCount: bottleCount),
            tier: tier,
            status: .available,
            schedule: schedule.isEmpty ? availableTime : schedule,
            notes: notes,
            donorRating: donorRating,
            isRecurring: isRecurring,
            availableTime: availableTime,
            claimedBy: nil,
            createdAt: Date(),
            bottlePhotoBase64: bottlePhotoBase64,
            locationPhotoBase64: locationPhotoBase64
        )
        try await db.collection("jobs").document(id).setData(payload.dictionary)
    }

    func completeJobInFirestore(
        _ job: BottleJob,
        bottleCount: Int,
        aiVerified: Bool,
        collectorId: String,
        proofPhotoBase64: String?
    ) async throws {
        try await db.collection("jobs").document(job.id).setData([
            "status": "completed",
            "completedAt": Timestamp(date: Date()),
            "actualBottleCount": bottleCount,
            "aiVerified": aiVerified
        ], merge: true)

        let pickup = FirestorePickupRecord(
            id: UUID().uuidString,
            jobId: job.id,
            collectorId: collectorId,
            jobTitle: job.title,
            bottleCount: bottleCount,
            earnings: job.estimatedValue,
            review: aiVerified ? "AI verified pickup completed smoothly." : "Pickup completed successfully.",
            date: Date(),
            proofPhotoBase64: proofPhotoBase64
        )
        try await db.collection("pickups").document(pickup.id).setData(pickup.dictionary)

        try await db.collection("users").document(collectorId).setData([
            "totalEarnings": FieldValue.increment(job.estimatedValue),
            "totalBottlesDiverted": FieldValue.increment(Int64(bottleCount)),
            "totalBottles": FieldValue.increment(Int64(bottleCount)),
            "reviewCount": FieldValue.increment(Int64(1)),
            "reliabilityScore": 96.0,
            "onTimeRate": 98.0,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func demandMultiplier(for tier: JobTier, bottleCount: Int) -> Double {
        let base: Double
        switch tier {
        case .residential: base = 1.0
        case .bulk: base = 1.1
        case .commercial: base = 1.2
        }
        let scarcityBonus = bottleCount > 250 ? 0.1 : 0
        return min(1.5, base + scarcityBonus)
    }
}

private struct FirestoreJobRecord {
    let id: String
    let donorId: String
    let title: String
    let latitude: Double
    let longitude: Double
    let address: String
    let bottleCount: Int
    let payout: Double
    let demandMultiplier: Double
    let tier: JobTier
    var status: JobStatus
    let schedule: String
    let notes: String
    let donorRating: Double
    let isRecurring: Bool
    let availableTime: String
    var claimedBy: String?
    let createdAt: Date
    let bottlePhotoBase64: String?
    let locationPhotoBase64: String?

    init?(_ data: [String: Any], id: String) {
        let bottleValue = (data["bottleCount"] as? Int) ?? (data["bottleCount"] as? NSNumber)?.intValue
        let payoutValue = (data["payout"] as? Double) ?? (data["payout"] as? NSNumber)?.doubleValue
        let donorRatingValue = (data["donorRating"] as? Double) ?? (data["donorRating"] as? NSNumber)?.doubleValue
        let donorIdValue = (data["donorId"] as? String) ?? (data["donor_id"] as? String)
        let bottleCountValue = bottleValue ?? (data["bottle_count"] as? Int) ?? (data["bottle_count"] as? NSNumber)?.intValue
        let payoutRaw = payoutValue ?? (data["estimatedValue"] as? Double) ?? (data["estimatedValue"] as? NSNumber)?.doubleValue
        let demandMultiplier = (data["demandMultiplier"] as? Double) ?? (data["demandMultiplier"] as? NSNumber)?.doubleValue ?? 1.0
        let statusRawValue = ((data["status"] as? String) ?? "available").lowercased()
        let mappedStatus: JobStatus
        switch statusRawValue {
        case "open", "available": mappedStatus = .available
        case "accepted", "claimed": mappedStatus = .claimed
        case "completed": mappedStatus = .completed
        case "cancelled", "canceled": mappedStatus = .cancelled
        default: mappedStatus = .available
        }
        let locationTuple: (Double, Double)? = {
            if let lat = (data["latitude"] as? Double) ?? (data["latitude"] as? NSNumber)?.doubleValue,
               let lon = (data["longitude"] as? Double) ?? (data["longitude"] as? NSNumber)?.doubleValue {
                return (lat, lon)
            }
            if let geo = data["location"] as? GeoPoint {
                return (geo.latitude, geo.longitude)
            }
            return nil
        }()
        let tierRaw = (data["tier"] as? String) ?? JobTier.residential.rawValue
        let tier = JobTier(rawValue: tierRaw) ?? .residential
        let schedule = (data["schedule"] as? String) ?? "Flexible"
        let notes = (data["notes"] as? String) ?? ""
        let donorRating = donorRatingValue ?? 5.0
        let isRecurring = (data["isRecurring"] as? Bool) ?? false
        let availableTime = (data["availableTime"] as? String) ?? "Available now"
        guard
            let donorId = donorIdValue,
            let title = data["title"] as? String,
            let latitude = locationTuple?.0,
            let longitude = locationTuple?.1,
            let address = data["address"] as? String,
            let bottleCount = bottleCountValue,
            let payout = payoutRaw
        else { return nil }

        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else {
            createdAt = Date()
        }

        self.id = id
        self.donorId = donorId
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.bottleCount = bottleCount
        self.payout = payout
        self.demandMultiplier = demandMultiplier
        self.tier = tier
        self.status = mappedStatus
        self.schedule = schedule
        self.notes = notes
        self.donorRating = donorRating
        self.isRecurring = isRecurring
        self.availableTime = availableTime
        self.claimedBy = data["claimedBy"] as? String
        self.createdAt = createdAt
        self.bottlePhotoBase64 = (data["bottlePhotoBase64"] as? String) ?? (data["bottle_photo_base64"] as? String)
        self.locationPhotoBase64 = (data["locationPhotoBase64"] as? String) ?? (data["location_photo_base64"] as? String)
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.init(data, id: document.documentID)
    }

    init(
        id: String,
        donorId: String,
        title: String,
        latitude: Double,
        longitude: Double,
        address: String,
        bottleCount: Int,
        payout: Double,
        demandMultiplier: Double,
        tier: JobTier,
        status: JobStatus,
        schedule: String,
        notes: String,
        donorRating: Double,
        isRecurring: Bool,
        availableTime: String,
        claimedBy: String?,
        createdAt: Date,
        bottlePhotoBase64: String?,
        locationPhotoBase64: String?
    ) {
        self.id = id
        self.donorId = donorId
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.bottleCount = bottleCount
        self.payout = payout
        self.demandMultiplier = demandMultiplier
        self.tier = tier
        self.status = status
        self.schedule = schedule
        self.notes = notes
        self.donorRating = donorRating
        self.isRecurring = isRecurring
        self.availableTime = availableTime
        self.claimedBy = claimedBy
        self.createdAt = createdAt
        self.bottlePhotoBase64 = bottlePhotoBase64
        self.locationPhotoBase64 = locationPhotoBase64
    }

    var job: BottleJob {
        BottleJob(
            id: id,
            donorId: donorId,
            title: title,
            location: GeoLocation(longitude: longitude, latitude: latitude),
            address: address,
            bottleCount: bottleCount,
            payout: payout,
            demandMultiplier: demandMultiplier,
            tier: tier,
            status: status,
            schedule: schedule,
            notes: notes,
            donorRating: donorRating,
            isRecurring: isRecurring,
            availableTime: availableTime,
            claimedBy: claimedBy,
            createdAt: createdAt,
            distance: nil,
            bottlePhotoBase64: bottlePhotoBase64,
            locationPhotoBase64: locationPhotoBase64
        )
    }

    var dictionary: [String: Any] {
        let firestoreStatus: String
        switch status {
        case .available: firestoreStatus = "open"
        case .claimed: firestoreStatus = "accepted"
        case .completed: firestoreStatus = "completed"
        case .cancelled: firestoreStatus = "cancelled"
        default: firestoreStatus = status.rawValue
        }
        return [
            "donorId": donorId,
            "title": title,
            "latitude": latitude,
            "longitude": longitude,
            "location": GeoPoint(latitude: latitude, longitude: longitude),
            "address": address,
            "bottleCount": bottleCount,
            "payout": payout,
            "demandMultiplier": demandMultiplier,
            "estimatedValue": payout * max(demandMultiplier, 1.0),
            "tier": tier.rawValue,
            "status": firestoreStatus,
            "schedule": schedule,
            "notes": notes,
            "donorRating": donorRating,
            "isRecurring": isRecurring,
            "availableTime": availableTime,
            "claimedBy": claimedBy ?? NSNull(),
            "createdAt": Timestamp(date: createdAt),
            "bottlePhotoBase64": bottlePhotoBase64 as Any,
            "locationPhotoBase64": locationPhotoBase64 as Any
        ]
    }
}

private struct FirestorePickupRecord {
    let id: String
    let jobId: String
    let collectorId: String
    let jobTitle: String
    let bottleCount: Int
    let earnings: Double
    let review: String
    let date: Date
    let proofPhotoBase64: String?

    init(
        id: String,
        jobId: String,
        collectorId: String,
        jobTitle: String,
        bottleCount: Int,
        earnings: Double,
        review: String,
        date: Date,
        proofPhotoBase64: String?
    ) {
        self.id = id
        self.jobId = jobId
        self.collectorId = collectorId
        self.jobTitle = jobTitle
        self.bottleCount = bottleCount
        self.earnings = earnings
        self.review = review
        self.date = date
        self.proofPhotoBase64 = proofPhotoBase64
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        guard
            let jobId = data["jobId"] as? String,
            let collectorId = data["collectorId"] as? String,
            let jobTitle = data["jobTitle"] as? String,
            let bottleCount = (data["bottleCount"] as? Int) ?? (data["bottleCount"] as? NSNumber)?.intValue,
            let earnings = (data["earnings"] as? Double) ?? (data["earnings"] as? NSNumber)?.doubleValue,
            let review = data["review"] as? String
        else { return nil }
        let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
        self.init(
            id: document.documentID,
            jobId: jobId,
            collectorId: collectorId,
            jobTitle: jobTitle,
            bottleCount: bottleCount,
            earnings: earnings,
            review: review,
            date: date,
            proofPhotoBase64: data["proofPhotoBase64"] as? String
        )
    }

    var history: PickupHistory {
        PickupHistory(
            id: id,
            jobTitle: jobTitle,
            date: date,
            bottleCount: bottleCount,
            earnings: earnings,
            rating: 5.0,
            review: review,
            proofPhotoBase64: proofPhotoBase64
        )
    }

    var dictionary: [String: Any] {
        [
            "jobId": jobId,
            "collectorId": collectorId,
            "jobTitle": jobTitle,
            "bottleCount": bottleCount,
            "earnings": earnings,
            "review": review,
            "date": Timestamp(date: date),
            "proofPhotoBase64": proofPhotoBase64 as Any
        ]
    }
}

private struct FirestoreUserRecord {
    let id: String
    let name: String
    let email: String
    let type: UserType
    let rating: Double
    let totalBottles: Int
    let totalEarnings: Double
    let reviewCount: Int
    let joinDate: Date
    let profilePhotoBase64: String?

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        let roleRaw = (data["role"] as? String) ?? (data["type"] as? String) ?? UserType.collector.rawValue
        let type = UserType(rawValue: roleRaw) ?? .collector
        let joinDate = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.id = document.documentID
        self.name = (data["name"] as? String) ?? "User"
        self.email = (data["email"] as? String) ?? ""
        self.type = type
        self.rating = (data["rating"] as? Double) ?? (data["rating"] as? NSNumber)?.doubleValue ?? 4.8
        self.totalBottles = (data["totalBottlesDiverted"] as? Int)
            ?? (data["totalBottlesDiverted"] as? NSNumber)?.intValue
            ?? (data["totalBottles"] as? Int)
            ?? (data["totalBottles"] as? NSNumber)?.intValue
            ?? 0
        self.totalEarnings = (data["totalEarnings"] as? Double) ?? (data["totalEarnings"] as? NSNumber)?.doubleValue ?? 0
        self.reviewCount = (data["reviewCount"] as? Int) ?? (data["reviewCount"] as? NSNumber)?.intValue ?? 0
        self.joinDate = joinDate
        self.profilePhotoBase64 = (data["profilePhotoBase64"] as? String) ?? (data["profilePhotoUrl"] as? String)
    }

    var user: UserProfile {
        UserProfile(
            id: id,
            name: name,
            email: email,
            type: type,
            rating: rating,
            totalBottles: totalBottles,
            totalEarnings: totalEarnings,
            reviewCount: reviewCount,
            joinDate: joinDate,
            badges: [],
            profilePhotoUrl: profilePhotoBase64
        )
    }
}
#endif
