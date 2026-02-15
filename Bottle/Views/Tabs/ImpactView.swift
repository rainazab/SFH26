//
//  ImpactView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import Charts

struct ImpactView: View {
    @EnvironmentObject var dataService: DataService
    private var impactStats: ImpactStats { dataService.impactStats }
    
    private func medalForRank(_ rank: Int) -> String? {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CITY IMPACT TODAY")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(dataService.cityBottlesToday)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("bottles diverted")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(String(format: "%.1f", dataService.cityCO2Today)) kg")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandBlueLight)
                                Text("CO₂ saved")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        MiniStatCard(
                            value: "\(dataService.platformStats.totalActiveUsers)",
                            subtitle: "active users",
                            icon: "person.3.fill",
                            color: .brandBlueLight
                        )
                        MiniStatCard(
                            value: "\(dataService.platformStats.totalJobsCompleted)",
                            subtitle: "posts completed",
                            icon: "checkmark.seal.fill",
                            color: .brandGreen
                        )
                    }
                    .padding(.horizontal)

                    // Hero Stats
                    VStack(spacing: 20) {
                        HeroStatCard(
                            title: "Total Impact",
                            value: "\(impactStats.totalBottles)",
                            subtitle: "bottles rescued",
                            icon: "cylinder.fill",
                            color: .brandGreen
                        )
                        
                        HStack(spacing: 15) {
                            MiniStatCard(
                                value: "\(impactStats.totalBottles)",
                                subtitle: "bottles tracked",
                                icon: "cylinder.fill",
                                color: .brandGreen
                            )
                            
                            MiniStatCard(
                                value: "\(String(format: "%.1f", impactStats.co2Saved))kg",
                                subtitle: "CO₂ saved",
                                icon: "leaf.fill",
                                color: .brandGreenDark
                            )
                        }
                    }
                    .padding()
                    
                    // Ranking Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.title)
                                .foregroundColor(Color(hex: "FFD700"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Top \(impactStats.rankPercentile)% in Oakland")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("You're making a real difference!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        Text("Your impact is equivalent to:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            EquivalenceRow(icon: "tree.fill", text: "Planting \(impactStats.treesEquivalent) trees", color: .brandGreenDark)
                            EquivalenceRow(icon: "car.fill", text: "Removing 1 car from road for 2 weeks", color: .brandBlueLight)
                            EquivalenceRow(icon: "lightbulb.fill", text: "Powering a home for 45 days", color: Color(hex: "FF9800"))
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    // Neighborhood Leaderboard
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("NEIGHBORHOOD LEADERBOARD")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("This Month")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 12) {
                            ForEach(Array(dataService.leaderboardUsers.enumerated()), id: \.element.id) { index, user in
                                LeaderboardRow(
                                    rank: index + 1,
                                    name: user.name,
                                    bottles: user.totalBottles,
                                    isCurrentUser: user.id == dataService.currentUser?.id,
                                    medal: medalForRank(index + 1)
                                )
                            }
                            if dataService.leaderboardUsers.isEmpty {
                                Text("Leaderboard will populate as users complete pickups.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share on Social Media")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandGreen.opacity(0.15))
                            .foregroundColor(Color.brandGreen)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    // Badges
                    VStack(alignment: .leading, spacing: 16) {
                        Text("BADGES EARNED")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(SampleData.shared.collectorProfile.badges) { badge in
                                BadgeCard(badge: badge)
                            }
                            
                            // Locked badge
                            LockedBadgeCard(name: "Oakland Hero", requirement: "Collect 500+ bottles")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    // Weekly Chart
                    VStack(alignment: .leading, spacing: 16) {
                        Text("THIS WEEK'S ACTIVITY")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        WeeklyChartView()
                            .frame(height: 200)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Impact")
            .background(Color(.systemGray6))
        }
    }
}

struct HeroStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }
}

struct MiniStatCard: View {
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

struct EquivalenceRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let name: String
    let bottles: Int
    let isCurrentUser: Bool
    let medal: String?
    
    var body: some View {
        HStack(spacing: 12) {
            if let medal = medal {
                Text(medal)
                    .font(.title3)
            } else {
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }
            
            Text(name)
                .font(.subheadline)
                .fontWeight(isCurrentUser ? .bold : .regular)
            
            Spacer()
            
            Text("\(bottles)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.brandGreen)
        }
        .padding()
        .background(isCurrentUser ? Color.brandGreen.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct BadgeCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.icon)
                .font(.largeTitle)
                .foregroundColor(Color(hex: "FFD700"))
            
            Text(badge.name)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(badge.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct LockedBadgeCard: View {
    let name: String
    let requirement: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(requirement)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .opacity(0.6)
    }
}

struct WeeklyChartView: View {
    let weekData = [
        (day: "Mon", bottles: 320),
        (day: "Tue", bottles: 450),
        (day: "Wed", bottles: 280),
        (day: "Thu", bottles: 520),
        (day: "Fri", bottles: 680),
        (day: "Sat", bottles: 590),
        (day: "Sun", bottles: 380)
    ]
    
    var body: some View {
        Chart(weekData, id: \.day) { data in
            BarMark(
                x: .value("Day", data.day),
                y: .value("Bottles", data.bottles)
            )
            .foregroundStyle(Color.brandGreen)
            .cornerRadius(5)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

#Preview {
    ImpactView()
        .environmentObject(DataService.shared)
}
