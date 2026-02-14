//
//  JobDetailView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import MapKit

struct JobDetailView: View {
    let job: BottleJob
    @Environment(\.dismiss) var dismiss
    @State private var showingClaimSuccess = false
    
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
                        
                        // Payout & Bottles
                        HStack(spacing: 30) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PAYOUT")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(String(format: "%.0f", job.payout))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(Color(hex: "00C853"))
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
                        InfoRow(icon: "location", title: "Distance", value: String(format: "%.1f mi", job.distance))
                        
                        if job.isRecurring {
                            HStack {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundColor(Color(hex: "FF6B6B"))
                                Text("Recurring Job")
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
                                showingClaimSuccess = true
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Claim This Job")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "00C853"))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                            }
                            
                            Button(action: {}) {
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
                                    Text("Contact Donor")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(15)
                            }
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
        .alert("Job Claimed!", isPresented: $showingClaimSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("You've successfully claimed this pickup. Check your Activity tab for details.")
        }
    }
    
    func tierColor(_ tier: JobTier) -> Color {
        switch tier {
        case .residential: return Color(hex: "4CAF50")
        case .bulk: return Color(hex: "2196F3")
        case .commercial: return Color(hex: "9C27B0")
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "00C853"))
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
}
