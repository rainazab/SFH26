//
//  JobListView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct JobListView: View {
    @State private var searchText = ""
    @State private var selectedTier: JobTier? = nil
    @State private var showingFilters = false
    @State private var minPayout = 0.0
    @State private var maxDistance = 10.0
    @State private var selectedJob: BottleJob?
    @State private var showingJobDetail = false
    @Environment(\.colorScheme) var colorScheme
    
    let jobs = SampleData.shared.jobs
    
    var filteredJobs: [BottleJob] {
        jobs.filter { job in
            (selectedTier == nil || job.tier == selectedTier) &&
            job.payout >= minPayout &&
            (job.distance ?? 0) <= maxDistance &&
            (searchText.isEmpty || job.title.localizedCaseInsensitiveContains(searchText))
        }
        .sorted { $0.payout > $1.payout }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                        Text("Total Payout")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(Int(filteredJobs.reduce(0) { $0 + $1.payout }))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "00C853"))
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
                            color: Color(hex: "9C27B0")
                        ) {
                            selectedTier = .commercial
                        }
                        
                        FilterPill(
                            title: "Bulk",
                            isSelected: selectedTier == .bulk,
                            color: Color(hex: "2196F3")
                        ) {
                            selectedTier = .bulk
                        }
                        
                        FilterPill(
                            title: "Residential",
                            isSelected: selectedTier == .residential,
                            color: Color(hex: "4CAF50")
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
                            JobCard(job: job)
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
                FiltersView(minPayout: $minPayout, maxDistance: $maxDistance)
            }
            .sheet(isPresented: $showingJobDetail) {
                if let job = selectedJob {
                    JobDetailView(job: job)
                }
            }
        }
    }
}

struct JobCard: View {
    let job: BottleJob
    
    var body: some View {
            HStack(spacing: 16) {
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
                
                // Payout
                VStack(spacing: 4) {
                    Text("$\(Int(job.payout))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "00C853"))
                    Text("payout")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    func tierColor(_ tier: JobTier) -> Color {
        switch tier {
        case .residential: return Color(hex: "4CAF50")
        case .bulk: return Color(hex: "2196F3")
        case .commercial: return Color(hex: "9C27B0")
        }
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
    @Binding var minPayout: Double
    @Binding var maxDistance: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Minimum Payout") {
                    HStack {
                        Text("$\(Int(minPayout))")
                            .fontWeight(.semibold)
                        Slider(value: $minPayout, in: 0...100, step: 5)
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
                        minPayout = 0
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
}
