//
//  Config.swift
//  Bottle
//
//  Backend Configuration
//

import Foundation

enum Config {
    // MARK: - Firebase
    // Firebase config is loaded from GoogleService-Info.plist
    // No environment variables needed
    
    // MARK: - MongoDB Atlas
    static let mongoAppID = ProcessInfo.processInfo.environment["MONGO_APP_ID"] ?? ""
    static let mongoAPIKey = ProcessInfo.processInfo.environment["MONGO_API_KEY"] ?? ""
    static let mongoClusterURL = ProcessInfo.processInfo.environment["MONGO_CLUSTER_URL"] ?? ""
    static let mongoDatabaseName = "bottle_redemption"
    
    // MARK: - Gemini AI
    static let geminiAPIKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    
    // MARK: - Google Maps
    static let googleMapsAPIKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"] ?? ""
    
    // MARK: - Validation
    static func validateConfiguration() -> [String] {
        var missingKeys: [String] = []
        
        // Only validate keys we're actually using
        if geminiAPIKey.isEmpty { missingKeys.append("GEMINI_API_KEY") }
        if googleMapsAPIKey.isEmpty { missingKeys.append("GOOGLE_MAPS_API_KEY") }
        
        // MongoDB is optional for demo (using mock data)
        // if mongoAppID.isEmpty { missingKeys.append("MONGO_APP_ID") }
        // if mongoAPIKey.isEmpty { missingKeys.append("MONGO_API_KEY") }
        // if mongoClusterURL.isEmpty { missingKeys.append("MONGO_CLUSTER_URL") }
        
        return missingKeys
    }
    
    static var isConfigured: Bool {
        validateConfiguration().isEmpty
    }
}
