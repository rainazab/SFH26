//
//  MongoDBService.swift
//  Bottle
//
//  MongoDB Atlas Integration (for MongoDB Track)
//

import Foundation
import CoreLocation

class MongoDBService {
    private let baseURL: String
    private let apiKey: String
    private let databaseName = "bottle_redemption"
    
    init() {
        self.baseURL = Config.mongoClusterURL
        self.apiKey = Config.mongoAPIKey
    }
    
    // MARK: - Jobs Collection
    
    /// Fetch nearby jobs using MongoDB's $near geospatial query
    /// DEMO THIS FOR MONGODB TRACK!
    func fetchNearbyJobs(
        longitude: Double,
        latitude: Double,
        radiusMiles: Double
    ) async throws -> [BottleJob] {
        let radiusMeters = radiusMiles * 1609.34
        
        let filter: [String: Any] = [
            "location": [
                "$near": [
                    "$geometry": [
                        "type": "Point",
                        "coordinates": [longitude, latitude]  // [lng, lat] ORDER!
                    ],
                    "$maxDistance": radiusMeters
                ]
            ],
            "status": "available"
        ]
        
        let request = MongoRequest(
            collection: "jobs",
            database: databaseName,
            dataSource: "Cluster0",
            filter: filter,
            limit: 50
        )
        
        let jobs: [BottleJob] = try await performFind(request: request)
        
        // Calculate distances for each job
        let userLocation = CLLocation(latitude: latitude, longitude: longitude)
        return jobs.map { job in
            var jobWithDistance = job
            let jobLocation = CLLocation(latitude: job.location.latitude, longitude: job.location.longitude)
            jobWithDistance.distance = userLocation.distance(from: jobLocation) / 1609.34  // meters to miles
            return jobWithDistance
        }
    }
    
    /// Create a new job (for donors)
    func createJob(_ job: BottleJob, donorId: String) async throws -> String {
        var jobDict: [String: Any] = [
            "donor_id": donorId,
            "title": job.title,
            "location": [
                "type": "Point",
                "coordinates": [job.location.longitude, job.location.latitude]
            ],
            "address": job.address,
            "bottle_count": job.bottleCount,
            "payout": job.payout,
            "tier": job.tier.rawValue,
            "status": JobStatus.available.rawValue,
            "schedule": job.schedule,
            "notes": job.notes,
            "donor_rating": job.donorRating,
            "is_recurring": job.isRecurring,
            "available_time": job.availableTime,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let request = MongoRequest(
            collection: "jobs",
            database: databaseName,
            dataSource: "Cluster0",
            document: jobDict
        )
        
        let response: MongoInsertResponse = try await performInsertOne(request: request)
        return response.insertedId
    }
    
    /// Claim a job (for collectors)
    func claimJob(jobId: String, collectorId: String) async throws -> Bool {
        let filter = ["_id": ["$oid": jobId]]
        let update = [
            "$set": [
                "status": JobStatus.claimed.rawValue,
                "claimed_by": collectorId,
                "claimed_at": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        
        try await performUpdateOne(
            collection: "jobs",
            filter: filter,
            update: update
        )
        
        // Create claim document
        let claimDoc: [String: Any] = [
            "job_id": jobId,
            "collector_id": collectorId,
            "status": ClaimStatus.pending.rawValue,
            "claimed_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        _ = try await performInsertOne(
            collection: "claims",
            document: claimDoc
        )
        
        return true
    }
    
    /// Complete pickup with AI verification
    func completePickup(
        claimId: String,
        photoUrl: String,
        userCount: Int,
        aiCount: Int,
        verified: Bool
    ) async throws -> Bool {
        let variance = abs(aiCount - userCount)
        let percentVariance = Double(variance) / Double(userCount)
        
        // Strict verification: 20% tolerance
        guard percentVariance <= 0.20 else {
            throw MongoError.countMismatch(expected: userCount, actual: aiCount)
        }
        
        let filter = ["_id": ["$oid": claimId]]
        let update = [
            "$set": [
                "status": ClaimStatus.completed.rawValue,
                "completed_at": ISO8601DateFormatter().string(from: Date()),
                "bottles_collected": userCount,
                "ai_verified_count": aiCount,
                "photo_url": photoUrl,
                "verification": [
                    "verified": verified,
                    "variance": variance,
                    "percent_variance": percentVariance
                ]
            ]
        ]
        
        try await performUpdateOne(
            collection: "claims",
            filter: filter,
            update: update
        )
        
        return true
    }
    
    // MARK: - Users Collection
    
    func createUser(_ user: UserProfile) async throws -> String {
        let userDict: [String: Any] = [
            "_id": user.id,  // Use Firebase UID
            "name": user.name,
            "email": user.email,
            "type": user.type.rawValue,
            "rating": user.rating,
            "total_bottles": user.totalBottles,
            "total_earnings": user.totalEarnings,
            "join_date": ISO8601DateFormatter().string(from: user.joinDate),
            "badges": []
        ]
        
        let response: MongoInsertResponse = try await performInsertOne(
            collection: "users",
            document: userDict
        )
        
        return response.insertedId
    }
    
    func fetchUser(userId: String) async throws -> UserProfile? {
        let filter = ["_id": userId]
        
        let request = MongoRequest(
            collection: "users",
            database: databaseName,
            dataSource: "Cluster0",
            filter: filter
        )
        
        let response: MongoFindResponse<UserProfile> = try await performFindOne(request: request)
        return response.document
    }
    
    // MARK: - Impact Stats (for Climate Track)
    
    func updateImpactStats(
        userId: String,
        bottlesAdded: Int,
        co2Added: Double
    ) async throws {
        let impact = ClimateImpactCalculator.calculateImpact(bottles: bottlesAdded)
        
        let filter = ["_id": userId]
        let update = [
            "$inc": [
                "total_bottles": bottlesAdded,
                "co2_saved": co2Added,
                "water_saved": impact.waterSavedGallons,
                "waste_reduced": impact.wasteReducedKg
            ],
            "$set": [
                "trees_equivalent": impact.treesEquivalent,
                "days_car_removed": impact.daysCarRemoved,
                "days_home_powered": impact.daysHomePowered,
                "last_updated": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        
        try await performUpdateOne(
            collection: "impact_stats",
            filter: filter,
            update: update
        )
    }
    
    func fetchImpactStats(userId: String) async throws -> ImpactStats? {
        let filter = ["_id": userId]
        
        let request = MongoRequest(
            collection: "impact_stats",
            database: databaseName,
            dataSource: "Cluster0",
            filter: filter
        )
        
        let response: MongoFindResponse<ImpactStats> = try await performFindOne(request: request)
        return response.document
    }
    
    // MARK: - Claims Collection
    
    func fetchUserClaims(userId: String) async throws -> [Claim] {
        let filter = ["collector_id": userId]
        let sort = ["claimed_at": -1]  // Most recent first
        
        let request = MongoRequest(
            collection: "claims",
            database: databaseName,
            dataSource: "Cluster0",
            filter: filter,
            sort: sort,
            limit: 50
        )
        
        return try await performFind(request: request)
    }
    
    // MARK: - Private HTTP Methods
    
    private func performFind<T: Decodable>(request: MongoRequest) async throws -> [T] {
        var urlRequest = try createURLRequest(action: "find", request: request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MongoError.connectionFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw MongoError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(MongoFindResponse<T>.self, from: data)
        return result.documents
    }
    
    private func performFindOne<T: Decodable>(request: MongoRequest) async throws -> MongoFindResponse<T> {
        var urlRequest = try createURLRequest(action: "findOne", request: request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MongoError.connectionFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw MongoError.invalidResponse
        }
        
        return try JSONDecoder().decode(MongoFindResponse<T>.self, from: data)
    }
    
    private func performInsertOne<T: Codable>(request: MongoRequest) async throws -> MongoInsertResponse {
        performInsertOne(collection: request.collection, document: request.document!)
    }
    
    private func performInsertOne(collection: String, document: [String: Any]) async throws -> MongoInsertResponse {
        let requestBody: [String: Any] = [
            "collection": collection,
            "database": databaseName,
            "dataSource": "Cluster0",
            "document": document
        ]
        
        var urlRequest = try createURLRequest(action: "insertOne", body: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MongoError.connectionFailed
        }
        
        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw MongoError.invalidResponse
        }
        
        return try JSONDecoder().decode(MongoInsertResponse.self, from: data)
    }
    
    private func performUpdateOne(
        collection: String,
        filter: [String: Any],
        update: [String: Any]
    ) async throws {
        let requestBody: [String: Any] = [
            "collection": collection,
            "database": databaseName,
            "dataSource": "Cluster0",
            "filter": filter,
            "update": update
        ]
        
        var urlRequest = try createURLRequest(action: "updateOne", body: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MongoError.connectionFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw MongoError.invalidResponse
        }
    }
    
    private func createURLRequest(action: String, body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/action/\(action)") else {
            throw MongoError.connectionFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func createURLRequest(action: String, request: MongoRequest) throws -> URLRequest {
        var body: [String: Any] = [
            "collection": request.collection,
            "database": request.database,
            "dataSource": request.dataSource
        ]
        
        if let filter = request.filter {
            body["filter"] = filter
        }
        
        if let sort = request.sort {
            body["sort"] = sort
        }
        
        if let limit = request.limit {
            body["limit"] = limit
        }
        
        if let document = request.document {
            body["document"] = document
        }
        
        return try createURLRequest(action: action, body: body)
    }
}

// MARK: - Request/Response Models

struct MongoRequest {
    let collection: String
    let database: String
    let dataSource: String
    var filter: [String: Any]?
    var sort: [String: Int]?
    var limit: Int?
    var document: [String: Any]?
}

struct MongoFindResponse<T: Decodable>: Decodable {
    let documents: [T]
    let document: T?
}

struct MongoInsertResponse: Decodable {
    let insertedId: String
}

struct MongoUpdateResponse: Decodable {
    let matchedCount: Int
    let modifiedCount: Int
}
