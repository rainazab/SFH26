//
//  AppError.swift
//  Bottle
//
//  Created by Raina Zab on 2/13/26.
//

import Foundation

enum AppError: LocalizedError {
    case network(Error)
    case authentication(String)
    case mongodb(String)
    case storage(String)
    case gemini(String)
    case location(String)
    case validation(String)
    case unauthorized
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .authentication(let message):
            return "Authentication failed: \(message)"
        case .mongodb(let message):
            return "Database error: \(message)"
        case .storage(let message):
            return "Storage error: \(message)"
        case .gemini(let message):
            return "AI verification error: \(message)"
        case .location(let message):
            return "Location error: \(message)"
        case .validation(let message):
            return "Validation error: \(message)"
        case .unauthorized:
            return "You need to sign in to perform this action"
        case .notFound:
            return "Resource not found"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network:
            return "Check your internet connection and try again"
        case .authentication:
            return "Try signing in again or reset your password"
        case .mongodb:
            return "Please try again later or contact support"
        case .storage:
            return "Check your internet connection and try uploading again"
        case .gemini:
            return "Try taking another photo with better lighting"
        case .location:
            return "Enable location services in Settings"
        case .validation:
            return "Please check your input and try again"
        case .unauthorized:
            return "Sign in to continue"
        case .notFound:
            return "This item may have been removed"
        }
    }
}

enum MongoError: Error {
    case connectionFailed
    case invalidResponse
    case countMismatch(expected: Int, actual: Int)
    case notFound
}

enum GeminiError: LocalizedError {
    case missingAPIKey
    case imageProcessingFailed
    case invalidResponse
    case rateLimitExceeded
    case networkError
}

extension GeminiError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini AI is not configured. Please check your settings."
        case .imageProcessingFailed:
            return "Couldn't process image. Try taking a clearer photo."
        case .invalidResponse:
            return "AI couldn't analyze this photo. Enter count manually."
        case .rateLimitExceeded:
            return "Too many AI requests. Wait 1 minute or enter manually."
        case .networkError:
            return "Network error. Check connection and try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .rateLimitExceeded:
            return "Wait 60 seconds before trying AI count again."
        case .networkError:
            return "Check your internet connection."
        default:
            return "You can always enter the bottle count manually."
        }
    }
}
