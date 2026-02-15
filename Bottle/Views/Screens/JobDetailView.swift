//
//  JobDetailView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import MapKit
import UIKit

struct JobDetailView: View {
    let job: BottleJob
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var dataService: DataService
    @State private var showingClaimSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isClaiming = false
    @State private var etaText = "Calculating..."
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Image/Map Preview
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: job.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )))) {
                        Marker(job.title, coordinate: job.coordinate)
                            .tint(tierColor(job.tier))
                    }
                    .frame(height: 200)
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // Main Info Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: job.tier.icon)
                                .font(.title)
                                .foregroundColor(tierColor(job.tier))
                                .frame(width: 50, height: 50)
                                .background(tierColor(job.tier).opacity(0.1))
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(job.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Impact potential
                        HStack(spacing: 30) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CO₂ IMPACT")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: job.bottleCount))) kg")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(Color.brandBlueLight)
                                Text(impactContextText)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if job.demandMultiplier > 1.0 {
                                    Text("High-priority pickup (+\(Int((job.demandMultiplier - 1.0) * 100))% demand)")
                                        .font(.caption2)
                                        .foregroundColor(.brandGreen)
                                }
                            }
                            
                            Divider()
                                .frame(height: 50)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BOTTLES")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(job.bottleCount)")
                                    .font(.system(size: 36, weight: .bold))
                            }
                        }
                        
                        Divider()
                        
                        // Schedule
                        InfoRow(icon: "calendar", title: "Schedule", value: job.schedule)
                        InfoRow(icon: "clock", title: "Available", value: job.availableTime)
                        if let expiresAt = job.expiresAt {
                            InfoRow(icon: "timer", title: "Expires", value: expiresAt.formatted(date: .omitted, time: .shortened))
                        }
                        InfoRow(icon: "location", title: "Distance", value: String(format: "%.1f mi", job.distance ?? 0))
                        InfoRow(icon: "car.fill", title: "ETA", value: etaText)
                        
                        if job.isRecurring {
                            HStack {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundColor(Color(hex: "FF6B6B"))
                                Text("Recurring Post")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(Color(hex: "FF6B6B").opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        Divider()
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES FROM DONOR")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(job.notes)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }

                        if bottlePhotoImage != nil || locationPhotoImage != nil {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("PICKUP PHOTOS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        if let bottlePhotoImage {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Image(uiImage: bottlePhotoImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 160, height: 110)
                                                    .clipped()
                                                    .cornerRadius(10)
                                                Text("Bottles")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if let locationPhotoImage {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Image(uiImage: locationPhotoImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 160, height: 110)
                                                    .clipped()
                                                    .cornerRadius(10)
                                                Text("Location")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if let aiConfidence = job.aiConfidence {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("AI SIGNALS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Confidence: \(aiConfidence)%")
                                    .font(.subheadline)
                                if let materials = job.materialBreakdown {
                                    Text("Plastic \(materials.plastic) • Aluminum \(materials.aluminum) • Glass \(materials.glass)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Donor Rating
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DONOR RATING")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < Int(job.donorRating) ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .font(.subheadline)
                                    }
                                    Text(String(format: "%.1f", job.donorRating))
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                claimJob()
                            }) {
                                HStack {
                                    if isClaiming {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text(isClaiming ? "Claiming..." : "Claim This Collection")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brandGreen)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                            }
                            .disabled(isClaiming || !dataService.canClaimNewJob)
                            
                            Button(action: {
                                dataService.startNavigation(to: job)
                            }) {
                                HStack {
                                    Image(systemName: "location.fill")
                                    Text("Navigate There")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                            }
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Contact Host")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(15)
                            }
                            .disabled(true)
                        }
                        .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Collection Point Claimed!", isPresented: $showingClaimSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Impact pickup claimed. Coordinate handoff and verify in the Activity tab.")
        }
        .alert("Unable to Claim", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await calculateETA()
        }
    }
    
    func tierColor(_ tier: JobTier) -> Color {
        switch tier {
        case .residential: return .tierResidential
        case .bulk: return .tierBulk
        case .commercial: return .tierCommercial
        }
    }

    private func claimJob() {
        isClaiming = true
        Task {
            do {
                try await dataService.claimJob(job)
                await MainActor.run {
                    isClaiming = false
                    showingClaimSuccess = true
                }
            } catch {
                await MainActor.run {
                    isClaiming = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func calculateETA() async {
        guard let current = locationService.userLocation?.coordinate else {
            etaText = "Need location"
            return
        }
        if let eta = await dataService.estimatedTravelTime(to: job.coordinate, from: current) {
            let mins = Int(eta / 60.0)
            etaText = "\(mins) min drive"
        } else {
            etaText = "Unavailable"
        }
    }

    private var impactContextText: String {
        let co2 = ClimateImpactCalculator.co2Saved(bottles: job.bottleCount)
        switch co2 {
        case 0..<5:
            return "About \(Int(co2 * 12)) phone charges worth of carbon avoided."
        case 5..<25:
            return "Roughly \(Int(co2 / 0.4)) miles of car emissions avoided."
        default:
            return "Equivalent to around \(max(1, Int(co2 / 20))) tree(s) of annual absorption."
        }
    }

    private var bottlePhotoImage: UIImage? {
        guard let base64 = job.bottlePhotoBase64,
              let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private var locationPhotoImage: UIImage? {
        guard let base64 = job.locationPhotoBase64,
              let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.brandGreen)
                .frame(width: 30)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    JobDetailView(job: SampleData.shared.jobs[0])
        .environmentObject(LocationService())
        .environmentObject(DataService.shared)
}
