//
//  DonorHomeView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct DonorHomeView: View {
    @EnvironmentObject var dataService: DataService
    @AppStorage("bottlr.firstRunTip.host") private var showHostTip = true
    @State private var selectedClaimedPost: BottleJob?
    @State private var showClaimFeedbackSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if showHostTip {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.brandBlueLight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("First step")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Post your first collection point so nearby collectors can claim it.")
                                    .font(.subheadline)
                            }
                            Spacer()
                            Button {
                                showHostTip = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    NavigationLink(destination: DonorCreateJobView()) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Post Bottles")
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
                        Text("ACTIVE POST")
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

                    if let pendingFeedbackPost = pendingClaimedPosts.first {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COLLECTOR CLAIMED")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pendingFeedbackPost.title) was claimed")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Tell us if pickup happened in daytime and rate the collector.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                selectedClaimedPost = pendingFeedbackPost
                                showClaimFeedbackSheet = true
                            } label: {
                                Text("Review Claim")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.brandBlueLight.opacity(0.2))
                                    .foregroundColor(.brandBlueDark)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

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
            .sheet(isPresented: $showClaimFeedbackSheet) {
                if let selectedClaimedPost {
                    HostClaimFeedbackView(post: selectedClaimedPost)
                        .environmentObject(dataService)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppNotificationService.openCollectionPointNotification)) { notification in
                guard let postId = notification.userInfo?[AppNotificationService.postIDUserInfoKey] as? String else { return }
                guard let matched = pendingClaimedPosts.first(where: { $0.id == postId }) else { return }
                selectedClaimedPost = matched
                showClaimFeedbackSheet = true
            }
        }
    }

    private var pendingClaimedPosts: [BottleJob] {
        dataService.myPostedJobs.filter { $0.status == .claimed && $0.collectorRatingByHost == nil }
    }
}

struct HostClaimFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataService: DataService

    let post: BottleJob
    @State private var pickedInDaytime = true
    @State private var collectorRating = 5
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Collection Point") {
                    Text(post.title)
                        .font(.headline)
                    Text(post.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Pickup Details") {
                    Toggle("Pickup happened in daytime", isOn: $pickedInDaytime)
                    Picker("Collector rating", selection: $collectorRating) {
                        ForEach(1...5, id: \.self) { score in
                            Text("\(score) star\(score == 1 ? "" : "s")").tag(score)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView() }
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Claim Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn't submit feedback", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await dataService.submitHostClaimFeedback(
                    for: post,
                    pickedInDaytime: pickedInDaytime,
                    collectorRating: collectorRating
                )
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    DonorHomeView()
        .environmentObject(DataService.shared)
}
