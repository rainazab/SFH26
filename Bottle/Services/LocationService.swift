//
//  LocationService.swift
//  Bottle
//
//  Location Service using CoreLocation
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100  // Update every 100 meters
        
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // Geocode address to coordinates (Google Maps Geocoding API)
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        let apiKey = Config.googleMapsAPIKey
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=\(encodedAddress)&key=\(apiKey)") else {
            throw AppError.location("Invalid address")
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        
        guard let location = response.results.first?.geometry.location else {
            throw AppError.location("Address not found")
        }
        
        return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
    }
    
    // Reverse geocode coordinates to address
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        let apiKey = Config.googleMapsAPIKey
        let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(coordinate.latitude),\(coordinate.longitude)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        
        guard let address = response.results.first?.formattedAddress else {
            throw AppError.location("Unable to determine address")
        }
        
        return address
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            userLocation = locations.last
            errorMessage = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdatingLocation()
            case .denied, .restricted:
                errorMessage = "Location access denied. Enable in Settings."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Google Geocoding Response

struct GeocodingResponse: Codable {
    let results: [GeocodingResult]
}

struct GeocodingResult: Codable {
    let geometry: Geometry
    let formattedAddress: String
    
    enum CodingKeys: String, CodingKey {
        case geometry
        case formattedAddress = "formatted_address"
    }
}

struct Geometry: Codable {
    let location: LocationCoordinate
}

struct LocationCoordinate: Codable {
    let lat: Double
    let lng: Double
}
