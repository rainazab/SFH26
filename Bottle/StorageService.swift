//
//  StorageService.swift
//  Bottle
//
//  Firebase Storage Service
//

import Foundation
import UIKit
import FirebaseStorage

class StorageService {
    private let storage = Storage.storage()
    
    // MARK: - Upload Pickup Photo
    
    func uploadPickupPhoto(_ image: UIImage, claimId: String) async throws -> String {
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AppError.storage("Failed to compress image")
        }
        
        // Create reference
        let filename = "\(UUID().uuidString).jpg"
        let ref = storage.reference().child("pickups/\(claimId)/\(filename)")
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload
        do {
            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            throw AppError.storage(error.localizedDescription)
        }
    }
    
    // MARK: - Upload Profile Photo
    
    func uploadProfilePhoto(_ image: UIImage, userId: String) async throws -> String {
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
    }
    
    // MARK: - Delete Photo
    
    func deletePhoto(url: String) async throws {
        guard let fileRef = Storage.storage().reference(forURL: url) as StorageReference? else {
            throw AppError.storage("Invalid URL")
        }
        
        do {
            try await fileRef.delete()
        } catch {
            throw AppError.storage(error.localizedDescription)
        }
    }
}
