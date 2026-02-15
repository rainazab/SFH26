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
    @State private var hideActiveBanner = false
    @State private var minEstimatedValue = 0.0
    @State private var maxDistance = 10.0
    @State private var selectedJob: BottleJob?
    @State private var showingJobDetail = false
    @State private var claimCandidate: BottleJob?
    @State private var isClaiming = false
    @State private var showClaimError = false
    @State private var claimErrorMessage = ""
    @State private var activeClaimedJob: BottleJob?
    @State private var showActivePickupSheet = false
    
    private var baseJobs: [BottleJob] {
        if dataService.currentUser?.type == .collector {
            return dataService.jobsAvailableForClaim
        }
        return dataService.availableJobs
    }

    var filteredJobs: [BottleJob] {
        baseJobs.filter { job in
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
                if dataService.hasActiveJob && !hideActiveBanner {
                    HStack(spacing: 10) {
                        Text("Complete your active pickup before claiming another post.")
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
                        Button("View Active") {
                            activeClaimedJob = dataService.myClaimedJobs.first
                            showActivePickupSheet = activeClaimedJob != nil
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.25))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        Button {
                            hideActiveBanner = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                }

                // Stats Header
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Collection Points Nearby")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(filteredJobs.count)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Impact Potential")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: filteredJobs.reduce(0) { $0 + $1.bottleCount }))) kg CO₂")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color.brandBlueLight)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterPill(
                            title: "All Posts",
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
                        if filteredJobs.isEmpty {
                            JobsEmptyStateView(
                                icon: "mappin.slash.circle",
                                title: "No posts found",
                                message: "Try widening your distance filter or clearing search."
                            ) {
                                showingFilters = true
                            }
                        } else {
                            ForEach(filteredJobs) { job in
                                JobCard(
                                    job: job,
                                    canClaim: dataService.canClaimNewJob
                                ) {
                                    claimCandidate = job
                                }
                                    .onTapGesture {
                                        selectedJob = job
                                        showingJobDetail = true
                                    }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Posts")
            .searchable(text: $searchText, prompt: "Search posts...")
            .sheet(isPresented: $showingFilters) {
                FiltersView(minEstimatedValue: $minEstimatedValue, maxDistance: $maxDistance)
            }
            .sheet(isPresented: $showingJobDetail) {
                if let job = selectedJob {
                    JobDetailView(job: job)
                        .environmentObject(locationService)
                }
            }
            .sheet(isPresented: $showActivePickupSheet) {
                if let activeClaimedJob {
                    CompletePickupView(job: activeClaimedJob)
                }
            }
            .alert("Claim this collection?", isPresented: Binding(
                get: { claimCandidate != nil },
                set: { if !$0 { claimCandidate = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    claimCandidate = nil
                }
                Button("Claim") {
                    handleClaim()
                }
                .disabled(isClaiming)
            } message: {
                if let claimCandidate {
                    Text("Claim \(claimCandidate.bottleCount) bottles at \(claimCandidate.address)?")
                } else {
                    Text("Claim this collection?")
                }
            }
            .alert("Could not claim post", isPresented: $showClaimError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(claimErrorMessage)
            }
            .onReceive(NotificationCenter.default.publisher(for: AppNotificationService.openCollectionPointNotification)) { notification in
                guard let postId = notification.userInfo?[AppNotificationService.postIDUserInfoKey] as? String else { return }
                if let match = filteredJobs.first(where: { $0.id == postId }) ?? baseJobs.first(where: { $0.id == postId }) {
                    selectedJob = match
                    showingJobDetail = true
                }
            }
        }
    }

    private func handleClaim() {
        guard let claimCandidate else { return }
        isClaiming = true
        Task {
            do {
                try await dataService.claimJob(claimCandidate)
            } catch {
                claimErrorMessage = error.localizedDescription
                showClaimError = true
            }
            self.claimCandidate = nil
            isClaiming = false
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
                    if let expiresAt = job.expiresAt {
                        Text("Expires \(expiresAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Impact snapshot
                VStack(spacing: 4) {
                    Text("\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: job.bottleCount)))kg")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.brandBlueLight)
                    Text("CO₂ impact")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("$\(Int(job.estimatedValue)) est.")
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
                Text("Claim Collection Point")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canClaim ? Color.brandGreen : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!canClaim)
            .accessibilityLabel("Claim this post")
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

struct JobsEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Adjust Filters", action: action)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.brandGreen)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    JobListView()
        .environmentObject(LocationService())
}
