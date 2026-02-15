//
//  ActivityView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct ActivityView: View {
    @StateObject private var dataService = DataService.shared
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                HStack(spacing: 15) {
                    ActivityStatCard(
                        title: "Today",
                        value: "\(todayCompleted)",
                        subtitle: "drop-offs",
                        color: Color(hex: "00C853")
                    )
                    
                    ActivityStatCard(
                        title: "Completed",
                        value: "\(totalCompleted)",
                        subtitle: "verified pickups",
                        color: Color(hex: "2196F3")
                    )
                    
                    ActivityStatCard(
                        title: "Bottles",
                        value: "\(totalBottles)",
                        subtitle: "diverted",
                        color: Color(hex: "9C27B0")
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
                                    .background(selectedFilter == filter ? Color(hex: "00C853") : Color(.systemGray5))
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
                        if !dataService.myClaimedJobs.isEmpty {
                            ForEach(dataService.myClaimedJobs) { job in
                                ClaimedJobCard(job: job) {
                                    selectedClaimedJob = job
                                    showingCompletePickup = true
                                }
                                Divider().padding(.leading, 80)
                            }
                        }
                        
                        ForEach(dataService.completedJobs) { pickup in
                            ActivityCard(pickup: pickup)
                            Divider()
                                .padding(.leading, 80)
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .sheet(isPresented: $showingCompletePickup) {
                if let job = selectedClaimedJob {
                    CompletePickupView(job: job)
                }
            }
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
                    .fill(Color(hex: "00C853").opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "00C853"))
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
                
                if !pickup.review.isEmpty {
                    Text("\"\(pickup.review)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Verification summary
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(pickup.bottleCount) verified")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "00C853"))
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    ActivityView()
}
