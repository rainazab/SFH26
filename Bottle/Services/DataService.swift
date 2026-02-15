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
final class DataService: ObservableObject {
    static let shared = DataService()

    @Published var availableJobs: [BottleJob] = []
    @Published var myClaimedJobs: [BottleJob] = []
    @Published var myPostedJobs: [BottleJob] = []
    @Published var completedJobs: [PickupHistory] = []
    @Published var currentUser: UserProfile?
    @Published var impactStats: ImpactStats = .mockStats
    @Published var walletTransactions: [WalletTransaction] = []

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
        isFirestoreEnabled = true
        observeJobs()
        observePickups()
        #else
        isFirestoreEnabled = false
        bindFallbackState()
        #endif
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
    }

    private func refreshDerivedCollections() {
        guard let user = currentUser else { return }
        myPostedJobs = availableJobs.filter { $0.donorId == user.id }
        myClaimedJobs = availableJobs.filter { $0.claimedBy == user.id && $0.status == .claimed }
        recalculateImpactFromHistory()
    }

    private func recalculateImpactFromHistory() {
        let bottles = completedJobs.reduce(0) { $0 + $1.bottleCount }
        let value = completedJobs.reduce(0.0) { $0 + $1.earnings }
        let co2 = Double(bottles) * 0.045
        impactStats.totalBottles = bottles
        impactStats.totalEarnings = value
        impactStats.co2Saved = co2
        impactStats.treesEquivalent = Int(co2 / 20.0)
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
                    "status": JobStatus.available.rawValue,
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
            try await completeJobInFirestore(job, bottleCount: bottleCount, aiVerified: aiVerified, collectorId: user.id)
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
            amount: job.payout,
            bottleCount: bottleCount
        )
        walletTransactions.insert(transaction, at: 0)
        persistWallet()
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
        availableTime: String
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
                availableTime: availableTime
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
    }
}

#if canImport(FirebaseFirestore)
private extension DataService {
    func observeJobs() {
        jobsListener?.remove()
        jobsListener = db.collection("jobs").addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let docs = snapshot?.documents else { return }
            var parsed = docs.compactMap(FirestoreJobRecord.init(document:)).map(\.job)
            if let userCoordinate = self.userCoordinate {
                parsed = self.withDistances(parsed, from: userCoordinate)
            }
            self.availableJobs = parsed.filter { $0.status != .completed && $0.status != .cancelled }
            self.refreshDerivedCollections()
        }
    }

    func observePickups() {
        guard let userId = currentUser?.id else { return }
        pickupsListener?.remove()
        pickupsListener = db.collection("pickups")
            .whereField("collectorId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents else { return }
                self.completedJobs = docs
                    .compactMap(FirestorePickupRecord.init(document:))
                    .map(\.history)
                    .sorted { $0.date > $1.date }
                self.recalculateImpactFromHistory()
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
        availableTime: String
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
            tier: tier,
            status: .available,
            schedule: schedule.isEmpty ? availableTime : schedule,
            notes: notes,
            donorRating: donorRating,
            isRecurring: isRecurring,
            availableTime: availableTime,
            claimedBy: nil,
            createdAt: Date()
        )
        try await db.collection("jobs").document(id).setData(payload.dictionary)
    }

    func completeJobInFirestore(_ job: BottleJob, bottleCount: Int, aiVerified: Bool, collectorId: String) async throws {
        try await db.collection("jobs").document(job.id).setData([
            "status": JobStatus.completed.rawValue,
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
            earnings: job.payout,
            review: aiVerified ? "AI verified pickup completed smoothly." : "Pickup completed successfully.",
            date: Date()
        )
        try await db.collection("pickups").document(pickup.id).setData(pickup.dictionary)
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
    let tier: JobTier
    var status: JobStatus
    let schedule: String
    let notes: String
    let donorRating: Double
    let isRecurring: Bool
    let availableTime: String
    var claimedBy: String?
    let createdAt: Date

    init?(_ data: [String: Any], id: String) {
        let bottleValue = (data["bottleCount"] as? Int) ?? (data["bottleCount"] as? NSNumber)?.intValue
        let payoutValue = (data["payout"] as? Double) ?? (data["payout"] as? NSNumber)?.doubleValue
        let donorRatingValue = (data["donorRating"] as? Double) ?? (data["donorRating"] as? NSNumber)?.doubleValue
        guard
            let donorId = data["donorId"] as? String,
            let title = data["title"] as? String,
            let latitude = (data["latitude"] as? Double) ?? (data["latitude"] as? NSNumber)?.doubleValue,
            let longitude = (data["longitude"] as? Double) ?? (data["longitude"] as? NSNumber)?.doubleValue,
            let address = data["address"] as? String,
            let bottleCount = bottleValue,
            let payout = payoutValue,
            let tierRaw = data["tier"] as? String,
            let tier = JobTier(rawValue: tierRaw),
            let statusRaw = data["status"] as? String,
            let status = JobStatus(rawValue: statusRaw),
            let schedule = data["schedule"] as? String,
            let notes = data["notes"] as? String,
            let donorRating = donorRatingValue,
            let isRecurring = data["isRecurring"] as? Bool,
            let availableTime = data["availableTime"] as? String
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
        self.tier = tier
        self.status = status
        self.schedule = schedule
        self.notes = notes
        self.donorRating = donorRating
        self.isRecurring = isRecurring
        self.availableTime = availableTime
        self.claimedBy = data["claimedBy"] as? String
        self.createdAt = createdAt
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
        tier: JobTier,
        status: JobStatus,
        schedule: String,
        notes: String,
        donorRating: Double,
        isRecurring: Bool,
        availableTime: String,
        claimedBy: String?,
        createdAt: Date
    ) {
        self.id = id
        self.donorId = donorId
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.bottleCount = bottleCount
        self.payout = payout
        self.tier = tier
        self.status = status
        self.schedule = schedule
        self.notes = notes
        self.donorRating = donorRating
        self.isRecurring = isRecurring
        self.availableTime = availableTime
        self.claimedBy = claimedBy
        self.createdAt = createdAt
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
            tier: tier,
            status: status,
            schedule: schedule,
            notes: notes,
            donorRating: donorRating,
            isRecurring: isRecurring,
            availableTime: availableTime,
            claimedBy: claimedBy,
            createdAt: createdAt,
            distance: nil
        )
    }

    var dictionary: [String: Any] {
        [
            "donorId": donorId,
            "title": title,
            "latitude": latitude,
            "longitude": longitude,
            "address": address,
            "bottleCount": bottleCount,
            "payout": payout,
            "tier": tier.rawValue,
            "status": status.rawValue,
            "schedule": schedule,
            "notes": notes,
            "donorRating": donorRating,
            "isRecurring": isRecurring,
            "availableTime": availableTime,
            "claimedBy": claimedBy ?? NSNull(),
            "createdAt": Timestamp(date: createdAt)
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

    init(
        id: String,
        jobId: String,
        collectorId: String,
        jobTitle: String,
        bottleCount: Int,
        earnings: Double,
        review: String,
        date: Date
    ) {
        self.id = id
        self.jobId = jobId
        self.collectorId = collectorId
        self.jobTitle = jobTitle
        self.bottleCount = bottleCount
        self.earnings = earnings
        self.review = review
        self.date = date
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
            date: date
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
            review: review
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
            "date": Timestamp(date: date)
        ]
    }
}
#endif
