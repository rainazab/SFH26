//
//  DonorHomeView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct DonorHomeView: View {
    @StateObject private var dataService = DataService.shared
    @State private var bottleCount = ""
    @State private var selectedTimeframe = "This weekend"
    @State private var showingPostSuccess = false
    
    let timeframes = ["Now", "Today", "Tomorrow", "This weekend", "This week", "Anytime"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    VStack(spacing: 12) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "00C853"))
                        
                        Text("Turn Your Bottles\nInto Impact")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Help local collectors recover recyclable bottles and reduce waste")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Quick Post Card
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Quick Post")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How many bottles?")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    TextField("Enter amount", text: $bottleCount)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Text("bottles")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("When can they pick up?")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Menu {
                                    ForEach(timeframes, id: \.self) { time in
                                        Button(time) {
                                            selectedTimeframe = time
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedTimeframe)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                .foregroundColor(.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Where?")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "00C853"))
                                    Text("1234 Oak St, San Francisco")
                                    Spacer()
                                }
                                .padding()
                                .background(Color(hex: "00C853").opacity(0.15))
                                .cornerRadius(10)
                            }
                            
                            NavigationLink(destination: DonorCreateJobView()) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Post Now")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "00C853"))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    // Impact Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("YOUR IMPACT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            ImpactStat(icon: "cylinder.fill", value: "\(dataService.impactStats.totalBottles)", label: "bottles donated", color: Color(hex: "00C853"))
                            ImpactStat(icon: "dollarsign.circle.fill", value: "$\(Int(dataService.impactStats.totalEarnings))", label: "est. redemption value", color: Color(hex: "FF9800"))
                        }
                        
                        HStack(spacing: 20) {
                            ImpactStat(icon: "leaf.fill", value: "23kg", label: "CO₂ saved", color: Color(hex: "4CAF50"))
                            ImpactStat(icon: "chart.bar.fill", value: "Top 5%", label: "in Oakland", color: Color(hex: "2196F3"))
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Next Milestone")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(max(dataService.impactStats.totalBottles + 80, 500)) bottles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(dataService.impactStats.totalBottles), total: Double(max(dataService.impactStats.totalBottles + 80, 500)))
                            .tint(Color(hex: "00C853"))
                        
                        Text("🏆 Unlock \"Oakland Hero\" badge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                    
                    // Recent Pickups
                    VStack(alignment: .leading, spacing: 16) {
                        Text("RECENT PICKUPS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            RecentPickupRow(name: "Miguel", bottles: 20, review: "Great guy, on time!")
                            Divider()
                            RecentPickupRow(name: "Sarah", bottles: 35, review: "So grateful, thank you")
                            Divider()
                            RecentPickupRow(name: "David", bottles: 18, review: "Very professional!")
                        }
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
            .navigationTitle("Post Bottles")
            .background(Color(.systemGray6))
        }
        .alert("Bottles Posted!", isPresented: $showingPostSuccess) {
            Button("OK") {}
        } message: {
            Text("Your bottles are now available for pickup. You'll be notified when someone claims them.")
        }
    }
}

struct ImpactStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecentPickupRow: View {
    let name: String
    let bottles: Int
    let review: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "00C853"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(name) picked up \(bottles) bottles")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "00C853"))
            }
            
            Text("\"\(review)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }
}

#Preview {
    DonorHomeView()
}
