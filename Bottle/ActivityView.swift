//
//  ActivityView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct ActivityView: View {
    let pickupHistory = SampleData.shared.pickupHistory
    @State private var selectedFilter: ActivityFilter = .all
    
    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case pending = "Pending"
        case upcoming = "Upcoming"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                HStack(spacing: 15) {
                    ActivityStatCard(
                        title: "Today",
                        value: "$52",
                        subtitle: "520 bottles",
                        color: Color(hex: "00C853")
                    )
                    
                    ActivityStatCard(
                        title: "This Week",
                        value: "$179",
                        subtitle: "1,790 bottles",
                        color: Color(hex: "2196F3")
                    )
                    
                    ActivityStatCard(
                        title: "This Month",
                        value: "$342",
                        subtitle: "3,420 bottles",
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
                        ForEach(pickupHistory) { pickup in
                            ActivityCard(pickup: pickup)
                            Divider()
                                .padding(.leading, 80)
                        }
                    }
                }
            }
            .navigationTitle("Activity")
        }
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
            
            // Earnings
            VStack(alignment: .trailing, spacing: 4) {
                Text("+$\(String(format: "%.0f", pickup.earnings))")
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
