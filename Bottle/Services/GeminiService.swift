//
//  GeminiService.swift
//  Bottle
//
//  Gemini AI Integration (for Gemini API Track)
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

class GeminiService {
    private let apiKey: String
    private let apiURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    init() {
        self.apiKey = Config.geminiAPIKey
    }
    
    // MARK: - Primary Feature: Bottle Counting
    /// DEMO THIS FOR GEMINI TRACK!
    func countBottles(from image: UIImage) async throws -> BottleCountResult {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageProcessingFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        // Craft prompt for optimal results
        let prompt = """
        You are an expert bottle counter for a recycling marketplace app.
        
        Count ALL bottles and cans in this image. Include:
        - Glass bottles (clear, brown, green)
        - Plastic bottles (water, soda, juice)
        - Aluminum cans
        - If bottles are in closed bags, estimate based on bag size:
          * Small kitchen bag (13 gal) = ~15 bottles
          * Large kitchen bag (30 gal) = ~30 bottles
          * Industrial bag (55 gal) = ~50 bottles
        
        Be conservative in estimates. When in doubt, round down.
        
        Return ONLY a JSON object with this EXACT structure (no markdown, no extra text):
        {
          "count": <number>,
          "confidence": <0-100>,
          "breakdown": {
            "visible": <number>,
            "estimated_in_bags": <number>
          },
          "materials": {
            "plastic": <number>,
            "aluminum": <number>,
            "glass": <number>
          },
          "notes": "<brief description of what you see>"
        }
        
        Example response:
        {"count": 45, "confidence": 85, "breakdown": {"visible": 30, "estimated_in_bags": 15}, "materials": {"plastic": 20, "aluminum": 15, "glass": 10}, "notes": "30 clearly visible bottles plus 1 large bag containing approximately 15 bottles"}
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.4,
                "topK": 32,
                "topP": 1,
                "maxOutputTokens": 2048
            ]
        ]
        
        guard let url = URL(string: "\(apiURL)?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw GeminiError.rateLimitExceeded
            }
            throw GeminiError.invalidResponse
        }
        
        // Parse Gemini response
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        // Extract JSON from text (remove markdown if present)
        let cleanText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanText.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(BottleCountResult.self, from: jsonData)
        return result
    }
    
    // MARK: - Verification Feature
    /// Compare AI count vs user claim
    func verifyPickup(
        photo: UIImage,
        claimedCount: Int
    ) async throws -> VerificationResult {
        let aiResult = try await countBottles(from: photo)
        
        let variance = abs(aiResult.count - claimedCount)
        let percentVariance = Double(variance) / Double(max(claimedCount, 1))
        
        // Allow 20% variance (industry standard for recycling)
        let isValid = percentVariance <= 0.20
        let shouldFlag = percentVariance > 0.30  // Flag for manual review
        
        return VerificationResult(
            aiCount: aiResult.count,
            userCount: claimedCount,
            variance: variance,
            percentVariance: percentVariance,
            isValid: isValid,
            confidence: aiResult.confidence,
            shouldFlag: shouldFlag,
            breakdown: aiResult.breakdown,
            notes: aiResult.notes
        )
    }

    // MARK: - Donor Feature: CRV Recyclability Classification
    func classifyRecyclability(from image: UIImage) async throws -> RecyclabilityResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageProcessingFailed
        }
        let base64Image = imageData.base64EncodedString()

        let prompt = """
        You are helping a California bottle redemption app.
        Determine if the visible items are likely recyclable under CRV.

        Return ONLY valid JSON with this exact schema:
        {
          "isRecyclable": true,
          "estimatedValue": 4.5,
          "confidence": 0.92,
          "summary": "short reason"
        }
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "topK": 32,
                "topP": 1,
                "maxOutputTokens": 1024
            ]
        ]

        guard let url = URL(string: "\(apiURL)?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.invalidResponse
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }

        let cleanText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleanText.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        return try JSONDecoder().decode(RecyclabilityResult.self, from: jsonData)
    }
    
    // MARK: - Estimate from Description (Optional)
    func estimateFromDescription(_ description: String) async throws -> Int {
        let prompt = """
        Based on this description, estimate the number of bottles:
        "\(description)"
        
        Return only a number. If unclear, estimate conservatively (round down).
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        guard let url = URL(string: "\(apiURL)?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.invalidResponse
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        // Extract number from response
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        return numbers.first ?? 0
    }
}

// MARK: - Response Models

struct BottleCountResult: Codable {
    let count: Int
    let confidence: Int
    let breakdown: CountBreakdown
    let materials: MaterialBreakdown?
    let notes: String
}

struct CountBreakdown: Codable {
    let visible: Int
    let estimatedInBags: Int
    
    enum CodingKeys: String, CodingKey {
        case visible
        case estimatedInBags = "estimated_in_bags"
    }
}

struct MaterialBreakdown: Codable {
    let plastic: Int
    let aluminum: Int
    let glass: Int
}

struct VerificationResult {
    let aiCount: Int
    let userCount: Int
    let variance: Int
    let percentVariance: Double
    let isValid: Bool
    let confidence: Int
    let shouldFlag: Bool
    let breakdown: CountBreakdown
    let notes: String
    
    var statusMessage: String {
        if isValid {
            return "✅ Verified: Counts match within acceptable range"
        } else if shouldFlag {
            return "⚠️ Large discrepancy detected. Manual review required."
        } else {
            return "⚠️ Count mismatch. Please verify and resubmit."
        }
    }
}

struct RecyclabilityResult: Codable {
    let isRecyclable: Bool
    let estimatedValue: Double
    let confidence: Double
    let summary: String
}

// MARK: - Gemini API Response Structure

struct GeminiResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
    }
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String?
    }
}
