//
//  ActivityView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import UIKit

struct ActivityView: View {
    @EnvironmentObject var dataService: DataService
    @State private var selectedFilter: ActivityFilter = .all
    @State private var selectedClaimedJob: BottleJob?
    @State private var showingCompletePickup = false
    
    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case pending = "Pending"
        case upcoming = "Upcoming"
    }

    private var totalCompleted: Int {
        dataService.completedJobs.count
    }

    private var totalBottles: Int {
        dataService.completedJobs.reduce(0) { $0 + $1.bottleCount }
    }

    private var todayCompleted: Int {
        let cal = Calendar.current
        return dataService.completedJobs.filter { cal.isDateInToday($0.date) }.count
    }

    private var isCollector: Bool {
        dataService.currentUser?.type == .collector
    }

    private var displayedCompletedPickups: [PickupHistory] {
        switch selectedFilter {
        case .all, .completed:
            return dataService.completedJobs
        case .pending, .upcoming:
            return []
        }
    }

    private var displayedCollectorClaimedJobs: [BottleJob] {
        let claimed = dataService.myClaimedJobs
        switch selectedFilter {
        case .all:
            return claimed
        case .completed:
            return []
        case .pending:
            return claimed.filter { $0.status == .claimed || $0.status == .inProgress || $0.status == .in_progress || $0.status == .arrived }
        case .upcoming:
            return claimed.filter { $0.status == .matched }
        }
    }

    private var displayedHostPosts: [BottleJob] {
        let mine = dataService.myPostedJobs.sorted { $0.createdAt > $1.createdAt }
        switch selectedFilter {
        case .all:
            return mine.filter { $0.status != .completed && $0.status != .cancelled && $0.status != .expired }
        case .completed:
            return []
        case .pending:
            return mine.filter { $0.status == .claimed || $0.status == .matched || $0.status == .inProgress || $0.status == .in_progress || $0.status == .arrived }
        case .upcoming:
            return mine.filter { $0.status == .available || $0.status == .posted }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                HStack(spacing: 15) {
                    ActivityStatCard(
                        title: "Today",
                        value: "\(todayCompleted)",
                        subtitle: "drop-offs",
                        color: .brandGreen
                    )
                    
                    ActivityStatCard(
                        title: "Completed",
                        value: "\(totalCompleted)",
                        subtitle: "verified pickups",
                        color: .brandBlueLight
                    )
                    
                    ActivityStatCard(
                        title: "Bottles",
                        value: "\(totalBottles)",
                        subtitle: "diverted",
                        color: .tierCommercial
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ActivityFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                            }) {
                                Text(filter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.brandGreen : Color(.systemGray5))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                // Activity List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isCollector {
                            if !displayedCollectorClaimedJobs.isEmpty {
                                ForEach(displayedCollectorClaimedJobs) { job in
                                    ClaimedJobCard(job: job) {
                                        selectedClaimedJob = job
                                        showingCompletePickup = true
                                    }
                                    Divider().padding(.leading, 80)
                                }
                            }
                        } else {
                            if !displayedHostPosts.isEmpty {
                                ForEach(displayedHostPosts) { post in
                                    HostPostStatusCard(post: post)
                                    Divider().padding(.leading, 80)
                                }
                            }
                        }

                        ForEach(displayedCompletedPickups) { pickup in
                            ActivityCard(pickup: pickup)
                            Divider()
                                .padding(.leading, 80)
                        }

                        if displayedCollectorClaimedJobs.isEmpty && displayedHostPosts.isEmpty && displayedCompletedPickups.isEmpty {
                            Text("No items in this filter yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle(dataService.currentUser?.type == .collector ? "Pickups" : "History")
            .sheet(isPresented: $showingCompletePickup) {
                if let job = selectedClaimedJob {
                    CompletePickupView(job: job)
                }
            }
        }
    }
}

struct HostPostStatusCard: View {
    let post: BottleJob

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("\(post.bottleCount) bottles • \(post.address)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var statusText: String {
        switch post.status {
        case .available, .posted:
            return "Open and waiting for collectors"
        case .matched, .claimed:
            return "Claimed by a collector"
        case .inProgress, .in_progress, .arrived:
            return "Pickup in progress"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .expired:
            return "Expired"
        case .disputed:
            return "Disputed"
        }
    }

    private var statusIcon: String {
        switch post.status {
        case .available, .posted: return "clock.badge.checkmark.fill"
        case .matched, .claimed: return "person.crop.circle.badge.checkmark"
        case .inProgress, .in_progress, .arrived: return "arrow.triangle.2.circlepath.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled, .expired, .disputed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch post.status {
        case .available, .posted: return .brandBlueLight
        case .matched, .claimed: return .brandGreen
        case .inProgress, .in_progress, .arrived: return .orange
        case .completed: return .brandGreenDark
        case .cancelled, .expired, .disputed: return .red
        }
    }
}

struct ClaimedJobCard: View {
    let job: BottleJob
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(job.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Claimed • \(job.bottleCount) bottles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Ready for drop-off verification")
                    .font(.caption)
                    .foregroundColor(.brandGreen)
            }
            Spacer()
            Button("Complete") {
                onComplete()
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.brandGreen)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct ActivityStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct ActivityCard: View {
    let pickup: PickupHistory
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandGreen.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.brandGreen)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(pickup.jobTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(pickup.rating) ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    Text(String(format: "%.1f", pickup.rating))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(pickup.bottleCount) bottles • \(pickup.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if shouldShowReview(pickup.review) {
                    Text("\"\(pickup.review)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                }

                if let proofImage {
                    Image(uiImage: proofImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 90)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()
                        .cornerRadius(8)
                }

                if let aiConfidence = pickup.aiConfidence {
                    Text("AI confidence: \(aiConfidence)%")
                        .font(.caption2)
                        .foregroundColor(.brandBlueLight)
                }

                if let materials = pickup.materialBreakdown {
                    Text("Materials P\(materials.plastic) / A\(materials.aluminum) / G\(materials.glass)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Verification summary
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(pickup.bottleCount) verified")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.brandGreen)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var proofImage: UIImage? {
        guard let base64 = pickup.proofPhotoBase64,
              let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private func shouldShowReview(_ review: String) -> Bool {
        let trimmed = review.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let systemGeneratedReviews: Set<String> = [
            "Pickup completed successfully.",
            "AI verified pickup completed smoothly.",
            "Completed collection point"
        ]
        return !systemGeneratedReviews.contains(trimmed)
    }
}

#Preview {
    ActivityView()
        .environmentObject(DataService.shared)
}
