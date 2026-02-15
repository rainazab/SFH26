//
//  DonorHomeView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import MapKit

struct DonorHomeView: View {
    @EnvironmentObject var dataService: DataService
    @AppStorage("bottlr.firstRunTip.host") private var showHostTip = true
    @State private var postsMode: HostPostsMode = .list
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var selectedFeedbackPost: BottleJob?
    @State private var selectedPostForEdit: BottleJob?
    @State private var showFeedbackSheet = false
    @State private var showEditPostSheet = false
    @State private var postPendingDelete: BottleJob?
    @State private var showDeleteConfirmation = false
    @State private var showActionError = false
    @State private var actionErrorMessage = ""

    enum HostPostsMode: String, CaseIterable {
        case list = "List"
        case map = "Map"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if shouldShowHostTip {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.brandBlueDark)
                                    Text("First step")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.brandBlueDark)
                                }
                                Spacer()
                                Button {
                                    showHostTip = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.brandBlueDark.opacity(0.65))
                                }
                            }

                            Text("Post your first collection point so nearby collectors can claim it.")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.brandBlueLight.opacity(0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.brandBlueLight.opacity(0.35), lineWidth: 1)
                        )
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
                        HStack {
                            Text("ACTIVE POSTS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(activePosts.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Picker("View", selection: $postsMode) {
                            ForEach(HostPostsMode.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        if activePosts.isEmpty {
                            Text("No active posts right now.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        } else if postsMode == .map {
                            Map(position: $mapPosition) {
                                ForEach(activePosts) { post in
                                    Marker(post.title, coordinate: post.coordinate)
                                        .tint(Color.brandGreen)
                                }
                            }
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(activePosts.prefix(8)) { post in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(post.address)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("\(post.bottleCount) bottles • \(post.availableTime)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(stageLabel(for: post.status))
                                            .font(.caption2)
                                            .foregroundColor(.brandBlueLight)
                                        if canModifyPost(post) {
                                            HStack(spacing: 10) {
                                                Button {
                                                    selectedPostForEdit = post
                                                    showEditPostSheet = true
                                                } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 8)
                                                        .background(Color.brandBlueLight.opacity(0.18))
                                                        .foregroundColor(.brandBlueDark)
                                                        .cornerRadius(8)
                                                }
                                                Button(role: .destructive) {
                                                    postPendingDelete = post
                                                    showDeleteConfirmation = true
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 8)
                                                        .background(Color.red.opacity(0.12))
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    if let pendingFeedbackPost = pendingCompletedFeedbackPosts.first {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COMPLETED PICKUP")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pendingFeedbackPost.title) is complete")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Rate the collector to finalize trust score updates.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                selectedFeedbackPost = pendingFeedbackPost
                                showFeedbackSheet = true
                            } label: {
                                Text("Rate Collector")
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

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your Impact")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }

                        HStack(spacing: 12) {
                            impactMetricCard(
                                title: "Bottles diverted",
                                value: "\(dataService.impactStats.totalBottles)",
                                systemImage: "waterbottle.fill"
                            )
                            impactMetricCard(
                                title: "CO2 saved",
                                value: String(format: "%.1f kg", dataService.impactStats.co2Saved),
                                systemImage: "leaf.circle.fill"
                            )
                        }
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
            .sheet(isPresented: $showFeedbackSheet) {
                if let selectedFeedbackPost {
                    HostClaimFeedbackView(post: selectedFeedbackPost)
                        .environmentObject(dataService)
                }
            }
            .sheet(isPresented: $showEditPostSheet) {
                if let selectedPostForEdit {
                    DonorCreateJobView(existingPost: selectedPostForEdit)
                        .environmentObject(dataService)
                }
            }
            .confirmationDialog(
                "Delete this post?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let postPendingDelete else { return }
                    Task {
                        do {
                            try await dataService.deletePost(postPendingDelete)
                            self.postPendingDelete = nil
                        } catch {
                            self.actionErrorMessage = error.localizedDescription
                            self.showActionError = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    postPendingDelete = nil
                }
            } message: {
                Text("This removes the collection point from nearby collectors.")
            }
            .alert("Couldn't complete action", isPresented: $showActionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(actionErrorMessage)
            }
            .onReceive(NotificationCenter.default.publisher(for: AppNotificationService.openCollectionPointNotification)) { notification in
                guard let postId = notification.userInfo?[AppNotificationService.postIDUserInfoKey] as? String else { return }
                if let completedMatch = pendingCompletedFeedbackPosts.first(where: { $0.id == postId }) {
                    selectedFeedbackPost = completedMatch
                    showFeedbackSheet = true
                    return
                }
            }
            .onAppear {
                focusMapOnPosts()
                if hasPostedAny {
                    showHostTip = false
                }
            }
            .onChange(of: postsMode) { _, mode in
                if mode == .map {
                    focusMapOnPosts()
                }
            }
            .onChange(of: activePosts.count) { _, _ in
                if postsMode == .map {
                    focusMapOnPosts()
                }
                if hasPostedAny {
                    showHostTip = false
                }
            }
        }
    }

    private var pendingCompletedFeedbackPosts: [BottleJob] {
        dataService.myPostedJobs
            .filter {
                $0.status == .completed &&
                $0.collectorRatingByHost == nil &&
                ($0.claimedBy?.isEmpty == false)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var activePosts: [BottleJob] {
        dataService.myPostedJobs
            .filter { $0.status != .completed && $0.status != .cancelled && $0.status != .expired }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var hasPostedAny: Bool {
        !dataService.myPostedJobs.isEmpty
    }

    private var shouldShowHostTip: Bool {
        showHostTip && !hasPostedAny
    }

    private func stageLabel(for status: JobStatus) -> String {
        switch status {
        case .available, .posted: return "Stage: posted"
        case .claimed, .matched: return "Stage: claimed"
        case .inProgress, .in_progress, .arrived: return "Stage: in progress"
        case .completed: return "Stage: completed"
        case .cancelled: return "Stage: cancelled"
        case .expired: return "Stage: expired"
        case .disputed: return "Stage: disputed"
        }
    }

    private func canModifyPost(_ post: BottleJob) -> Bool {
        post.claimedBy == nil && (post.status == .available || post.status == .posted)
    }

    private func focusMapOnPosts() {
        guard let first = activePosts.first else { return }
        mapPosition = .region(
            MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
        )
    }

    @ViewBuilder
    private func impactMetricCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundColor(.brandGreen)
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
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
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { score in
                            Button {
                                collectorRating = score
                            } label: {
                                Image(systemName: score <= collectorRating ? "star.fill" : "star")
                                    .font(.title3)
                                    .foregroundColor(score <= collectorRating ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Selected: \(collectorRating) star\(collectorRating == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
