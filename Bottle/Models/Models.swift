//
//  Models.swift
//  Bottle
//
//  Created by Raina Zab on 2/13/26.
//

import Foundation
import MapKit

// MARK: - User Types
enum UserType: String, Codable {
    case donor
    case collector
}

// MARK: - Job Tier
enum JobTier: String, Codable {
    case residential
    case bulk
    case commercial
    
    var color: String {
        switch self {
        case .residential: return "green"
        case .bulk: return "blue"
        case .commercial: return "purple"
        }
    }
    
    var icon: String {
        switch self {
        case .residential: return "house.fill"
        case .bulk: return "building.2.fill"
        case .commercial: return "storefront.fill"
        }
    }
}

// MARK: - Job Status
enum JobStatus: String, Codable {
    case available
    case claimed
    case in_progress
    case arrived
    case completed
    case cancelled
}

// MARK: - Claim Status
enum ClaimStatus: String, Codable {
    case pending
    case accepted
    case in_progress
    case completed
    case disputed
}

// MARK: - GeoLocation (for coordinate storage)
struct GeoLocation: Codable {
    let type: String
    let coordinates: [Double]  // [longitude, latitude]
    
    init(longitude: Double, latitude: Double) {
        self.type = "Point"
        self.coordinates = [longitude, latitude]
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.type = "Point"
        self.coordinates = [coordinate.longitude, coordinate.latitude]
    }
    
    var coordinate: CLLocationCoordinate2D {
        guard coordinates.count == 2 else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
    
    var longitude: Double { coordinates[0] }
    var latitude: Double { coordinates[1] }
}

// MARK: - Bottle Job
struct BottleJob: Codable, Identifiable {
    let id: String
    let donorId: String
    let title: String
    let location: GeoLocation
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
    var distance: Double?
    var bottlePhotoBase64: String? = nil
    var locationPhotoBase64: String? = nil
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case donorId = "donor_id"
        case title, location, address
        case bottleCount = "bottle_count"
        case payout, tier, status, schedule, notes
        case donorRating = "donor_rating"
        case isRecurring = "is_recurring"
        case availableTime = "available_time"
        case claimedBy = "claimed_by"
        case createdAt = "created_at"
        case distance
        case bottlePhotoBase64 = "bottle_photo_base64"
        case locationPhotoBase64 = "location_photo_base64"
    }
}

// MARK: - User Profile
struct UserProfile: Codable, Identifiable {
    let id: String
    var name: String
    var email: String
    let type: UserType
    var rating: Double
    var totalBottles: Int
    var totalEarnings: Double
    let joinDate: Date
    var badges: [Badge]
    var fcmToken: String?
    var profilePhotoUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, type, rating
        case totalBottles = "total_bottles"
        case totalEarnings = "total_earnings"
        case joinDate = "join_date"
        case badges
        case fcmToken = "fcm_token"
        case profilePhotoUrl = "profile_photo_url"
    }
}

// MARK: - Badge
struct Badge: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let earnedDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, icon, description
        case earnedDate = "earned_date"
    }
}

// MARK: - Claim
struct Claim: Codable, Identifiable {
    let id: String
    let jobId: String
    let collectorId: String
    let donorId: String
    var status: ClaimStatus
    let claimedAt: Date
    var scheduledPickupTime: Date?
    var actualPickupTime: Date?
    var bottlesCollected: Int?
    var aiVerifiedCount: Int?
    let earnings: Double
    var collectorRating: Double?
    var donorRating: Double?
    var photoUrl: String?
    var completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case jobId = "job_id"
        case collectorId = "collector_id"
        case donorId = "donor_id"
        case status
        case claimedAt = "claimed_at"
        case scheduledPickupTime = "scheduled_pickup_time"
        case actualPickupTime = "actual_pickup_time"
        case bottlesCollected = "bottles_collected"
        case aiVerifiedCount = "ai_verified_count"
        case earnings
        case collectorRating = "collector_rating"
        case donorRating = "donor_rating"
        case photoUrl = "photo_url"
        case completedAt = "completed_at"
    }
}

// MARK: - Pickup History
struct PickupHistory: Codable, Identifiable {
    let id: String
    let jobTitle: String
    let date: Date
    let bottleCount: Int
    let earnings: Double
    let rating: Double
    let review: String
    var proofPhotoBase64: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case jobTitle = "job_title"
        case date
        case bottleCount = "bottle_count"
        case earnings, rating, review
        case proofPhotoBase64 = "proof_photo_base64"
    }
}

// MARK: - Impact Stats
struct ImpactStats: Codable {
    var totalBottles: Int
    var totalEarnings: Double
    var co2Saved: Double
    var treesEquivalent: Int
    var daysCarRemoved: Int
    var daysHomePowered: Int
    var rankPercentile: Int
    
    enum CodingKeys: String, CodingKey {
        case totalBottles = "total_bottles"
        case totalEarnings = "total_earnings"
        case co2Saved = "co2_saved"
        case treesEquivalent = "trees_equivalent"
        case daysCarRemoved = "days_car_removed"
        case daysHomePowered = "days_home_powered"
        case rankPercentile = "rank_percentile"
    }
}

// MARK: - Wallet Transaction
struct WalletTransaction: Codable, Identifiable {
    let id: String
    let date: Date
    let title: String
    let amount: Double
    let bottleCount: Int
}

// MARK: - Mock Data (Hackathon Demo)
extension BottleJob {
    static let mockJobs: [BottleJob] = [
        BottleJob(
            id: "1",
            donorId: "donor1",
            title: "Zeitgeist Bar",
            location: GeoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7699, longitude: -122.4213)),
            address: "199 Valencia St, SF",
            bottleCount: 500,
            payout: 50.0,
            tier: .commercial,
            status: .available,
            schedule: "Every Friday, 2-3pm",
            notes: "Bottles are bagged and by back door. Ring bell if you need help.",
            donorRating: 4.9,
            isRecurring: true,
            availableTime: "Next pickup: Feb 14",
            createdAt: Date(),
            distance: 1.2
        ),
        BottleJob(
            id: "2",
            donorId: "donor2",
            title: "Mission Bar",
            location: GeoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7544, longitude: -122.4185)),
            address: "2695 Mission St, SF",
            bottleCount: 350,
            payout: 35.0,
            tier: .commercial,
            status: .available,
            schedule: "Every Saturday, 10am",
            notes: "Meet at side entrance. Large bags provided.",
            donorRating: 4.8,
            isRecurring: true,
            availableTime: "Next pickup: Feb 15",
            createdAt: Date(),
            distance: 0.8
        ),
        BottleJob(
            id: "3",
            donorId: "donor3",
            title: "Oakland Community Center",
            location: GeoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712)),
            address: "450 Grand Ave, Oakland",
            bottleCount: 200,
            payout: 20.0,
            tier: .bulk,
            status: .available,
            schedule: "Monthly collection",
            notes: "Community event bottles. Thank you for helping!",
            donorRating: 5.0,
            isRecurring: true,
            availableTime: "Available now",
            createdAt: Date(),
            distance: 2.5
        ),
        BottleJob(
            id: "4",
            donorId: "donor4",
            title: "Sarah M.",
            location: GeoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4294)),
            address: "1234 Oak St, SF",
            bottleCount: 50,
            payout: 5.0,
            tier: .bulk,
            status: .available,
            schedule: "This weekend",
            notes: "Bottles in blue bag by garage. Thanks!",
            donorRating: 4.7,
            isRecurring: false,
            availableTime: "Anytime this weekend",
            createdAt: Date(),
            distance: 0.3
        ),
        BottleJob(
            id: "5",
            donorId: "donor5",
            title: "John D.",
            location: GeoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7709, longitude: -122.4294)),
            address: "567 Haight St, SF",
            bottleCount: 20,
            payout: 2.0,
            tier: .residential,
            status: .available,
            schedule: "Anytime this week",
            notes: "By front door in paper bag.",
            donorRating: 4.5,
            isRecurring: false,
            availableTime: "Flexible",
            createdAt: Date(),
            distance: 0.5
        ),
        BottleJob(
            id: "6",
            donorId: "donor6",
            title: "The Chapel",
            location: GeoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7599, longitude: -122.4213)),
            address: "777 Valencia St, SF",
            bottleCount: 600,
            payout: 60.0,
            tier: .commercial,
            status: .available,
            schedule: "Every Sunday, 11am",
            notes: "Concert venue. Lots of bottles after weekend shows.",
            donorRating: 4.9,
            isRecurring: true,
            availableTime: "Next pickup: Feb 16",
            createdAt: Date(),
            distance: 1.5
        ),
        BottleJob(
            id: "7",
            donorId: "donor7",
            title: "Apartment Building",
            location: GeoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7839, longitude: -122.4090)),
            address: "890 Market St, SF",
            bottleCount: 150,
            payout: 15.0,
            tier: .bulk,
            status: .available,
            schedule: "Bi-weekly",
            notes: "Building manager. Bottles in recycling room.",
            donorRating: 4.6,
            isRecurring: true,
            availableTime: "Available now",
            createdAt: Date(),
            distance: 1.8
        )
    ]
}

extension Badge {
    static let mockBadges: [Badge] = [
        Badge(id: "1", name: "Rising Star", icon: "star.fill", description: "Complete 10 pickups", earnedDate: Date().addingTimeInterval(-60*60*24*80)),
        Badge(id: "2", name: "Efficiency Expert", icon: "bolt.fill", description: "Earn $50+ in one day", earnedDate: Date().addingTimeInterval(-60*60*24*60)),
        Badge(id: "3", name: "Community Hero", icon: "heart.fill", description: "Collect 1000+ bottles", earnedDate: Date().addingTimeInterval(-60*60*24*30)),
        Badge(id: "4", name: "Perfect Week", icon: "checkmark.seal.fill", description: "5/5 ratings for 7 days", earnedDate: Date().addingTimeInterval(-60*60*24*20))
    ]
}

extension UserProfile {
    static let mockCollector = UserProfile(
        id: "collector1",
        name: "Miguel R.",
        email: "miguel@example.com",
        type: .collector,
        rating: 4.8,
        totalBottles: 3420,
        totalEarnings: 342.0,
        joinDate: Date().addingTimeInterval(-60*60*24*90),
        badges: Badge.mockBadges
    )
    
    static let mockDonor = UserProfile(
        id: "donor1",
        name: "Alex Chen",
        email: "alex@example.com",
        type: .donor,
        rating: 4.9,
        totalBottles: 450,
        totalEarnings: 45.0,
        joinDate: Date().addingTimeInterval(-60*60*24*120),
        badges: []
    )
}

extension PickupHistory {
    static let mockHistory: [PickupHistory] = [
        PickupHistory(id: "1", jobTitle: "Zeitgeist Bar", date: Date().addingTimeInterval(-60*60*24*2), bottleCount: 520, earnings: 52.0, rating: 5.0, review: "Professional, bottles were ready and organized"),
        PickupHistory(id: "2", jobTitle: "Mission Bar", date: Date().addingTimeInterval(-60*60*24*3), bottleCount: 340, earnings: 34.0, rating: 4.8, review: "Great guy, on time!"),
        PickupHistory(id: "3", jobTitle: "Sarah M.", date: Date().addingTimeInterval(-60*60*24*5), bottleCount: 48, earnings: 4.8, rating: 5.0, review: "So grateful, thank you"),
        PickupHistory(id: "4", jobTitle: "The Chapel", date: Date().addingTimeInterval(-60*60*24*9), bottleCount: 580, earnings: 58.0, rating: 4.9, review: "Always reliable and friendly")
    ]
}

extension ImpactStats {
    static let mockStats = ImpactStats(
        totalBottles: 3420,
        totalEarnings: 342.0,
        co2Saved: 156.2,
        treesEquivalent: 7,
        daysCarRemoved: 14,
        daysHomePowered: 45,
        rankPercentile: 5
    )
}

// MARK: - SampleData (for backward compatibility)
class SampleData {
    static let shared = SampleData()
    
    let jobs = BottleJob.mockJobs
    let collectorProfile = UserProfile.mockCollector
    let donorProfile = UserProfile.mockDonor
    let pickupHistory = PickupHistory.mockHistory
    let impactStats = ImpactStats.mockStats
}
