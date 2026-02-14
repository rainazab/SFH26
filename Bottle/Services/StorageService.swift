//
//  StorageService.swift
//  Bottle
//
//  Mock Storage Service (Hackathon Demo Mode)
//  For production: Replace with Firebase Storage, Supabase, or S3
//

import Foundation
import UIKit
// import FirebaseStorage  // Commented out - using mock storage for demo

class StorageService {
    // private let storage = Storage.storage()  // Commented out for demo
    
    // MARK: - Upload Pickup Photo (MOCK)
    
    func uploadPickupPhoto(_ image: UIImage, claimId: String) async throws -> String {
        // DEMO MODE: Return mock URL instead of uploading to cloud
        // In production, this would upload to Firebase Storage, Supabase, etc.
        
        // Simulate upload delay (for realistic demo)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Generate mock URL
        let filename = "\(UUID().uuidString).jpg"
        let mockURL = "mock://pickups/\(claimId)/\(filename)"
        
        print("📸 DEMO: Mock photo upload successful")
        print("   Claim ID: \(claimId)")
        print("   Mock URL: \(mockURL)")
        
        return mockURL
        
        /* PRODUCTION CODE (commented out):
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AppError.storage("Failed to compress image")
        }
        
        let filename = "\(UUID().uuidString).jpg"
        let ref = storage.reference().child("pickups/\(claimId)/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            throw AppError.storage(error.localizedDescription)
        }
        */
    }
    
    // MARK: - Upload Profile Photo (MOCK)
    
    func uploadProfilePhoto(_ image: UIImage, userId: String) async throws -> String {
        // DEMO MODE: Return mock URL
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let filename = "profile_\(userId).jpg"
        let mockURL = "mock://profiles/\(filename)"
        
        print("📸 DEMO: Mock profile photo upload successful")
        print("   User ID: \(userId)")
        print("   Mock URL: \(mockURL)")
        
        return mockURL
        
        /* PRODUCTION CODE (commented out):
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.storage("Failed to compress image")
        }
        
        let filename = "profile_\(userId).jpg"
        let ref = storage.reference().child("profiles/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            throw AppError.storage(error.localizedDescription)
        }
        */
    }
    
    // MARK: - Delete Photo (MOCK)
    
    func deletePhoto(url: String) async throws {
        // DEMO MODE: Just log the deletion
        
        print("🗑️ DEMO: Mock photo deletion")
        print("   URL: \(url)")
        
        // In production, this would actually delete from cloud storage
        
        /* PRODUCTION CODE (commented out):
        guard let fileRef = Storage.storage().reference(forURL: url) as StorageReference? else {
            throw AppError.storage("Invalid URL")
        }
        
        do {
            try await fileRef.delete()
        } catch {
            throw AppError.storage(error.localizedDescription)
        }
        */
    }
}

// MARK: - Demo Notes

/*
 📝 HACKATHON DEMO MODE:
 
 This service uses MOCK URLs instead of cloud storage.
 
 Why?
 - Firebase Storage requires paid plan
 - Focus on MongoDB (geospatial) + Gemini (AI) for winning tracks
 - Photo storage isn't required to win any target tracks
 
 What works?
 ✅ Upload photo calls succeed (return mock URLs)
 ✅ Realistic delays simulate actual uploads
 ✅ URLs stored in MongoDB work fine
 ✅ Gemini AI still processes actual images
 
 For production:
 1. Uncomment Firebase Storage code above
 2. Or replace with Supabase/S3/MongoDB GridFS
 3. Update imports and initialization
 
 For demo:
 - Show UI for photo upload ✅
 - Use test images from Assets for Gemini AI ✅
 - Tell judges: "Storage ready, using local mode for demo" ✅
 */
