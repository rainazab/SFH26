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

// MARK: - MongoDB GeoJSON Point
struct GeoLocation: Codable {
    let type: String
    let coordinates: [Double]  // [longitude, latitude] - ORDER MATTERS!
    
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

// MARK: - Bottle Job (MongoDB-compatible)
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
    var distance: Double?  // Calculated field, not stored in DB
    
    // Convenience computed property for MapKit
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case donorId = "donor_id"
        case title
        case location
        case address
        case bottleCount = "bottle_count"
        case payout
        case tier
        case status
        case schedule
        case notes
        case donorRating = "donor_rating"
        case isRecurring = "is_recurring"
        case availableTime = "available_time"
        case claimedBy = "claimed_by"
        case createdAt = "created_at"
        case distance
    }
}

// MARK: - User Profile (MongoDB-compatible)
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
        case name
        case email
        case type
        case rating
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
        case name
        case icon
        case description
        case earnedDate = "earned_date"
    }
}

// MARK: - Claim (Pickup tracking)
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

// MARK: - Pickup History (for display)
struct PickupHistory: Codable, Identifiable {
    let id: String
    let jobTitle: String
    let date: Date
    let bottleCount: Int
    let earnings: Double
    let rating: Double
    let review: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case jobTitle = "job_title"
        case date
        case bottleCount = "bottle_count"
        case earnings
        case rating
        case review
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

// MARK: - Sample Data (for fallback/demo)
class SampleData {
    static let shared = SampleData()
    
    // Keep existing sample data for fallback...
    let jobs: [BottleJob] = []
    let collectorProfile = UserProfile(
        id: "sample",
        name: "Miguel R.",
        email: "miguel@example.com",
        type: .collector,
        rating: 4.8,
        totalBottles: 3420,
        totalEarnings: 342.0,
        joinDate: Date().addingTimeInterval(-60*60*24*90),
        badges: []
    )
    
    let donorProfile = UserProfile(
        id: "sample",
        name: "Alex Chen",
        email: "alex@example.com",
        type: .donor,
        rating: 4.9,
        totalBottles: 450,
        totalEarnings: 45.0,
        joinDate: Date().addingTimeInterval(-60*60*24*120),
        badges: []
    )
    
    let pickupHistory: [PickupHistory] = []
    
    let impactStats = ImpactStats(
        totalBottles: 3420,
        totalEarnings: 342.0,
        co2Saved: 156.2,
        treesEquivalent: 7,
        daysCarRemoved: 14,
        daysHomePowered: 45,
        rankPercentile: 5
    )
}


// MARK: - Bottle Job
struct BottleJob: Identifiable {
    let id = UUID()
    let title: String
    let location: String
    let coordinate: CLLocationCoordinate2D
    let bottleCount: Int
    let payout: Double
    let tier: JobTier
    let distance: Double // miles
    let schedule: String
    let notes: String
    let donorRating: Double
    let isRecurring: Bool
    let availableTime: String
}

// MARK: - User Profile
struct UserProfile {
    var name: String
    var type: UserType
    var rating: Double
    var totalBottles: Int
    var totalEarnings: Double
    var joinDate: Date
    var badges: [Badge]
}

// MARK: - Badge
struct Badge: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let earnedDate: Date?
}

// MARK: - Pickup History
struct PickupHistory: Identifiable {
    let id = UUID()
    let jobTitle: String
    let date: Date
    let bottleCount: Int
    let earnings: Double
    let rating: Double
    let review: String
}

// MARK: - Impact Stats
struct ImpactStats {
    var totalBottles: Int
    var totalEarnings: Double
    var co2Saved: Double // kg
    var treesEquivalent: Int
    var rankPercentile: Int // Top X%
}

// MARK: - Sample Data
class SampleData {
    static let shared = SampleData()
    
    // Sample Jobs
    let jobs: [BottleJob] = [
        BottleJob(
            title: "Zeitgeist Bar",
            location: "199 Valencia St, SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7699, longitude: -122.4213),
            bottleCount: 500,
            payout: 50.0,
            tier: .commercial,
            distance: 1.2,
            schedule: "Every Friday, 2-3pm",
            notes: "Bottles are bagged and by back door. Ring bell if you need help.",
            donorRating: 4.9,
            isRecurring: true,
            availableTime: "Next pickup: Feb 14"
        ),
        BottleJob(
            title: "Mission Bar",
            location: "2695 Mission St, SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7544, longitude: -122.4185),
            bottleCount: 350,
            payout: 35.0,
            tier: .commercial,
            distance: 0.8,
            schedule: "Every Saturday, 10am",
            notes: "Meet at side entrance. Large bags provided.",
            donorRating: 4.8,
            isRecurring: true,
            availableTime: "Next pickup: Feb 15"
        ),
        BottleJob(
            title: "Oakland Community Center",
            location: "450 Grand Ave, Oakland",
            coordinate: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712),
            bottleCount: 200,
            payout: 20.0,
            tier: .bulk,
            distance: 2.5,
            schedule: "Monthly collection",
            notes: "Community event bottles. Thank you for helping!",
            donorRating: 5.0,
            isRecurring: true,
            availableTime: "Available now"
        ),
        BottleJob(
            title: "Sarah M.",
            location: "1234 Oak St, SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4294),
            bottleCount: 50,
            payout: 5.0,
            tier: .bulk,
            distance: 0.3,
            schedule: "This weekend",
            notes: "Bottles in blue bag by garage. Thanks!",
            donorRating: 4.7,
            isRecurring: false,
            availableTime: "Anytime this weekend"
        ),
        BottleJob(
            title: "John D.",
            location: "567 Haight St, SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7709, longitude: -122.4294),
            bottleCount: 20,
            payout: 2.0,
            tier: .residential,
            distance: 0.5,
            schedule: "Anytime this week",
            notes: "By front door in paper bag.",
            donorRating: 4.5,
            isRecurring: false,
            availableTime: "Flexible"
        ),
        BottleJob(
            title: "The Chapel",
            location: "777 Valencia St, SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7599, longitude: -122.4213),
            bottleCount: 600,
            payout: 60.0,
            tier: .commercial,
            distance: 1.5,
            schedule: "Every Sunday, 11am",
            notes: "Concert venue. Lots of bottles after weekend shows.",
            donorRating: 4.9,
            isRecurring: true,
            availableTime: "Next pickup: Feb 16"
        ),
        BottleJob(
            title: "Apartment Building",
            location: "890 Market St, SF",
            coordinate: CLLocationCoordinate2D(latitude: 37.7839, longitude: -122.4090),
            bottleCount: 150,
            payout: 15.0,
            tier: .bulk,
            distance: 1.8,
            schedule: "Bi-weekly",
            notes: "Building manager. Bottles in recycling room.",
            donorRating: 4.6,
            isRecurring: true,
            availableTime: "Available now"
        )
    ]
    
    // Sample User Profile (Collector)
    let collectorProfile = UserProfile(
        name: "Miguel R.",
        type: .collector,
        rating: 4.8,
        totalBottles: 3420,
        totalEarnings: 342.0,
        joinDate: Date().addingTimeInterval(-60*60*24*90), // 90 days ago
        badges: [
            Badge(name: "Rising Star", icon: "star.fill", description: "Complete 10 pickups", earnedDate: Date().addingTimeInterval(-60*60*24*80)),
            Badge(name: "Efficiency Expert", icon: "bolt.fill", description: "Earn $50+ in one day", earnedDate: Date().addingTimeInterval(-60*60*24*60)),
            Badge(name: "Community Hero", icon: "heart.fill", description: "Collect 1000+ bottles", earnedDate: Date().addingTimeInterval(-60*60*24*30)),
            Badge(name: "Perfect Week", icon: "checkmark.seal.fill", description: "5/5 ratings for 7 days", earnedDate: Date().addingTimeInterval(-60*60*24*20))
        ]
    )
    
    // Sample User Profile (Donor)
    let donorProfile = UserProfile(
        name: "Alex Chen",
        type: .donor,
        rating: 4.9,
        totalBottles: 450,
        totalEarnings: 45.0, // Earnings for collectors
        joinDate: Date().addingTimeInterval(-60*60*24*120), // 120 days ago
        badges: [
            Badge(name: "Generous Neighbor", icon: "gift.fill", description: "Donate 100+ bottles", earnedDate: Date().addingTimeInterval(-60*60*24*90)),
            Badge(name: "Sustainability Champion", icon: "leaf.fill", description: "Donate for 3 months", earnedDate: Date().addingTimeInterval(-60*60*24*30)),
            Badge(name: "Community Leader", icon: "person.3.fill", description: "Top 5% in your area", earnedDate: Date().addingTimeInterval(-60*60*24*15))
        ]
    )
    
    // Sample Pickup History
    let pickupHistory: [PickupHistory] = [
        PickupHistory(
            jobTitle: "Zeitgeist Bar",
            date: Date().addingTimeInterval(-60*60*24*2),
            bottleCount: 520,
            earnings: 52.0,
            rating: 5.0,
            review: "Professional, bottles were ready and organized"
        ),
        PickupHistory(
            jobTitle: "Mission Bar",
            date: Date().addingTimeInterval(-60*60*24*3),
            bottleCount: 340,
            earnings: 34.0,
            rating: 4.8,
            review: "Great guy, on time!"
        ),
        PickupHistory(
            jobTitle: "Sarah M.",
            date: Date().addingTimeInterval(-60*60*24*5),
            bottleCount: 48,
            earnings: 4.8,
            rating: 5.0,
            review: "So grateful, thank you"
        ),
        PickupHistory(
            jobTitle: "The Chapel",
            date: Date().addingTimeInterval(-60*60*24*9),
            bottleCount: 580,
            earnings: 58.0,
            rating: 4.9,
            review: "Always reliable and friendly"
        )
    ]
    
    // Impact Stats
    let impactStats = ImpactStats(
        totalBottles: 3420,
        totalEarnings: 342.0,
        co2Saved: 156.2, // kg
        treesEquivalent: 7,
        rankPercentile: 5
    )
}
