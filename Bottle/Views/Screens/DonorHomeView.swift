//
//  DonorHomeView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct DonorHomeView: View {
    @StateObject private var dataService = DataService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    NavigationLink(destination: DonorCreateJobView()) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Schedule Pickup")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandGreen)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("NEXT PICKUP")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let upcoming = dataService.myPostedJobs.first {
                            Text(upcoming.address)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(upcoming.bottleCount) bottles • \(upcoming.availableTime)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No active pickup yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("LAST IMPACT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(dataService.impactStats.totalBottles) bottles diverted")
                            .font(.headline)
                        Text("\(String(format: "%.1f", dataService.impactStats.co2Saved)) kg CO₂ saved")
                            .font(.subheadline)
                            .foregroundColor(.brandBlueLight)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .background(Color(.systemGray6))
        }
    }
}

#Preview {
    DonorHomeView()
}
