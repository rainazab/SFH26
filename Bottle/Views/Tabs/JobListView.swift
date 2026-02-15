//
//  JobListView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import UIKit

struct JobListView: View {
    @StateObject private var dataService = DataService.shared
    @EnvironmentObject var locationService: LocationService
    @State private var searchText = ""
    @State private var selectedTier: JobTier? = nil
    @State private var showingFilters = false
    @State private var minEstimatedValue = 0.0
    @State private var maxDistance = 10.0
    @State private var selectedJob: BottleJob?
    @State private var showingJobDetail = false
    @Environment(\.colorScheme) var colorScheme
    
    var filteredJobs: [BottleJob] {
        dataService.availableJobs.filter { job in
            (selectedTier == nil || job.tier == selectedTier) &&
            job.estimatedValue >= minEstimatedValue &&
            (job.distance ?? 0) <= maxDistance &&
            (searchText.isEmpty || job.title.localizedCaseInsensitiveContains(searchText))
        }
        .sorted { ($0.distance ?? 999) < ($1.distance ?? 999) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if dataService.hasActiveJob {
                    Text("Complete your current pickup before claiming another job.")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                }

                // Stats Header
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Jobs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(filteredJobs.count)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Est. Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(Int(filteredJobs.reduce(0) { $0 + $1.payout }))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color.brandGreen)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterPill(
                            title: "All Jobs",
                            isSelected: selectedTier == nil,
                            color: .gray
                        ) {
                            selectedTier = nil
                        }
                        
                        FilterPill(
                            title: "Commercial",
                            isSelected: selectedTier == .commercial,
                            color: .tierCommercial
                        ) {
                            selectedTier = .commercial
                        }
                        
                        FilterPill(
                            title: "Bulk",
                            isSelected: selectedTier == .bulk,
                            color: .tierBulk
                        ) {
                            selectedTier = .bulk
                        }
                        
                        FilterPill(
                            title: "Residential",
                            isSelected: selectedTier == .residential,
                            color: .tierResidential
                        ) {
                            selectedTier = .residential
                        }
                        
                        Button(action: { showingFilters = true }) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text("More")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(20)
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                // Job List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredJobs) { job in
                            JobCard(
                                job: job,
                                canClaim: dataService.canClaimNewJob
                            ) {
                                Task {
                                    try? await dataService.claimJob(job)
                                }
                            }
                                .onTapGesture {
                                    selectedJob = job
                                    showingJobDetail = true
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Jobs")
            .searchable(text: $searchText, prompt: "Search jobs...")
            .sheet(isPresented: $showingFilters) {
                FiltersView(minEstimatedValue: $minEstimatedValue, maxDistance: $maxDistance)
            }
            .sheet(isPresented: $showingJobDetail) {
                if let job = selectedJob {
                    JobDetailView(job: job)
                        .environmentObject(locationService)
                }
            }
        }
    }
}

struct JobCard: View {
    let job: BottleJob
    let canClaim: Bool
    let onClaim: () -> Void
    
    var body: some View {
            VStack(spacing: 12) {
            HStack(spacing: 16) {
                if let bottlePreview = bottlePreview {
                    Image(uiImage: bottlePreview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(12)
                }

                // Icon
                ZStack {
                    Circle()
                        .fill(tierColor(job.tier).opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: job.tier.icon)
                        .font(.title2)
                        .foregroundColor(tierColor(job.tier))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(job.title)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if job.isRecurring {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundColor(Color(hex: "FF6B6B"))
                                .font(.caption)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(job.bottleCount)", systemImage: "cylinder.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(String(format: "%.1f mi", job.distance ?? 0), systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(String(format: "%.1f", job.donorRating), systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(job.availableTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Estimated redemption value
                VStack(spacing: 4) {
                    Text("$\(Int(job.estimatedValue))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.brandGreen)
                    Text("est. value")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if job.demandMultiplier > 1.0 {
                        Text("+\(Int((job.demandMultiplier - 1.0) * 100))% demand")
                            .font(.caption2)
                            .foregroundColor(.brandBlueLight)
                    }
                }
            }
            
            Button(action: onClaim) {
                Text("Claim Job")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canClaim ? Color.brandGreen : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!canClaim)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    func tierColor(_ tier: JobTier) -> Color {
        switch tier {
        case .residential: return .tierResidential
        case .bulk: return .tierBulk
        case .commercial: return .tierCommercial
        }
    }

    private var bottlePreview: UIImage? {
        guard let base64 = job.bottlePhotoBase64,
              let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct FiltersView: View {
    @Binding var minEstimatedValue: Double
    @Binding var maxDistance: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Minimum Estimated Value") {
                    HStack {
                        Text("$\(Int(minEstimatedValue))")
                            .fontWeight(.semibold)
                        Slider(value: $minEstimatedValue, in: 0...100, step: 5)
                    }
                }
                
                Section("Maximum Distance") {
                    HStack {
                        Text("\(String(format: "%.1f", maxDistance)) mi")
                            .fontWeight(.semibold)
                        Slider(value: $maxDistance, in: 0.5...25, step: 0.5)
                    }
                }
                
                Section {
                    Button("Reset Filters") {
                        minEstimatedValue = 0
                        maxDistance = 10
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    JobListView()
        .environmentObject(LocationService())
}
