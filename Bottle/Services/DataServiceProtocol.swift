//
//  DataServiceProtocol.swift
//  Bottle
//
//  Single backend contract for UI/view models.
//

import Foundation
import CoreLocation

protocol DataServiceProtocol: AnyObject {
    // User
    func fetchUser(uid: String, completion: @escaping (UserProfile?) -> Void)
    func createUser(_ user: UserProfile, completion: @escaping (Bool) -> Void)

    // Jobs
    func fetchOpenJobs(completion: @escaping ([BottleJob]) -> Void)
    func fetchUserJobs(userId: String, completion: @escaping ([BottleJob]) -> Void)
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
        bottlePhotoBase64: String?,
        locationPhotoBase64: String?
    ) async throws
    func acceptJob(jobId: String, collectorId: String) async throws
    func completeJob(job: BottleJob, bottleCount: Int, proofPhotoBase64: String?) async throws

    // Location helpers
    func updateJobDistances(from userLocation: CLLocationCoordinate2D)
}
