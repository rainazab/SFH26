//
//  MapView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var dataService: DataService
    @Environment(\.colorScheme) private var colorScheme
    var onShowList: (() -> Void)? = nil
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    @State private var selectedJob: BottleJob?
    @State private var isPulsing = true
    @State private var todayCO2: Double = 0
    @State private var showNewJobToast = false
    @State private var hasAutoFramed = false
    @State private var toastPostID: String?

    private var jobs: [BottleJob] {
        if dataService.currentUser?.type == .collector {
            return dataService.jobsAvailableForClaim
        }
        return dataService.availableJobs
    }
    
    var closestCollectionPoint: BottleJob? {
        jobs
            .filter { $0.status == .available && $0.distance != nil }
            .min(by: { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) })
    }

    private var toastTitle: String {
        let count = max(1, dataService.latestNearbyPostCount)
        return count == 1 ? "New post nearby!" : "\(count) new posts nearby!"
    }

    private var completedCount: String {
        "\(dataService.completedJobs.count)"
    }

    private var pendingCount: String {
        "\(dataService.myClaimedJobs.count)"
    }

    private var currentRating: String {
        String(format: "%.1f", dataService.currentUser?.rating ?? 0)
    }
    
    var body: some View {
        ZStack {
            // Map
            Map(position: $position) {
                // Built-in user location marker (blue dot style)
                UserAnnotation()

                ForEach(jobs) { job in
                    Annotation(job.title, coordinate: job.coordinate) {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            selectedJob = job
                        }) {
                            ZStack {
                                // Pulse effect for high-value jobs
                                if job.estimatedValue > 30 {
                                    Circle()
                                        .fill(tierColor(job.tier).opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                                }
                                
                                Circle()
                                    .fill(tierColor(job.tier))
                                    .frame(width: 40, height: 40)
                                    .shadow(color: tierColor(job.tier).opacity(0.5), radius: job.estimatedValue > 30 ? 8 : 3)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: job.tier.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                    Text("\(job.bottleCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .accessibilityLabel("Open collection point details for \(job.title)")
                    }
                }
            }
            .ignoresSafeArea()
            
            // Bottom Stats Card
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TODAY'S IMPACT")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Animated counter
                            AnimatedNumber(value: todayCO2, format: "%.1f")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? Color.brandBlueLight : Color.brandBlueDark)
                            Text("kg CO₂ saved")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                                
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Text("\(dataService.completedJobs.reduce(0) { $0 + $1.bottleCount })")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("BOTTLES VERIFIED")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Quick Stats
                    HStack(spacing: 20) {
                        StatBadge(icon: "checkmark.circle.fill", value: completedCount, label: "Completed")
                        StatBadge(icon: "clock.fill", value: pendingCount, label: "Pending")
                        StatBadge(icon: "arrow.up.circle.fill", value: currentRating, label: "Rating")
                    }
                    
                    Divider()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.accentOrange)
                        if let closest = closestCollectionPoint, let distance = closest.distance {
                            Text("Closest collection point is \(String(format: "%.1f", distance)) mi away")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                openCollectionPoint(closest)
                            }) {
                                Text("GO")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentOrange)
                                    .cornerRadius(8)
                            }
                        } else {
                            Text("No collection points available")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {}) {
                                Text("GO")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray)
                                    .cornerRadius(8)
                            }
                            .disabled(true)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentOrange.opacity(0.15))
                    .cornerRadius(10)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 10)
                .padding()
            }
            
            // New Job Toast Notification
            if showNewJobToast {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.brandGreen)
                            .font(.title3)
                        Text(toastTitle)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("View") {
                            HapticManager.shared.impact(.light)
                            if let toastPostID, let match = jobs.first(where: { $0.id == toastPostID }) {
                                selectedJob = match
                            }
                            withAnimation {
                                showNewJobToast = false
                            }
                        }
                        .foregroundColor(.brandGreen)
                        .fontWeight(.semibold)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.15), radius: 10)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 100)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedJob) { job in
            JobDetailView(job: job)
                .environmentObject(locationService)
        }
        .onAppear {
            if let userLocation = locationService.userLocation?.coordinate {
                dataService.updateJobDistances(from: userLocation)
                position = .region(
                    MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            }
            autoFramePostsIfNeeded(force: true)
            let todayBottles = dataService.completedJobs.filter {
                Calendar.current.isDateInToday($0.date)
            }.reduce(0) { $0 + $1.bottleCount }
            todayCO2 = ClimateImpactCalculator.co2Saved(bottles: todayBottles)
        }
        .onChange(of: locationService.userLocation) { _, location in
            if let location {
                dataService.updateJobDistances(from: location.coordinate)
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                position = .region(region)
                autoFramePostsIfNeeded(force: false)
            }
        }
        .onChange(of: jobs.map(\.id)) { _, _ in
            autoFramePostsIfNeeded(force: false)
            openPendingCollectionPointIfPossible()
        }
        .onChange(of: dataService.latestNearbyPostID) { _, newValue in
            guard dataService.currentUser?.type == .collector, let newValue else { return }
            toastPostID = newValue
            withAnimation(.spring()) {
                showNewJobToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation {
                    showNewJobToast = false
                }
            }
        }
        .onChange(of: dataService.pendingCollectionPointID) { _, postId in
            guard postId != nil else { return }
            openPendingCollectionPointIfPossible()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNotificationService.openCollectionPointNotification)) { notification in
            guard let postId = notification.userInfo?[AppNotificationService.postIDUserInfoKey] as? String else { return }
            dataService.queueCollectionPointOpen(postId: postId)
        }
    }
    
    func tierColor(_ tier: JobTier) -> Color {
        switch tier {
        case .residential: return .tierResidential
        case .bulk: return .tierBulk
        case .commercial: return .tierCommercial
        }
    }

    private func autoFramePostsIfNeeded(force: Bool) {
        guard force || !hasAutoFramed else { return }
        guard !jobs.isEmpty else { return }

        var rect = MKMapRect.null
        for post in jobs.prefix(30) {
            let point = MKMapPoint(post.coordinate)
            let tiny = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            rect = rect.isNull ? tiny : rect.union(tiny)
        }

        if let user = locationService.userLocation?.coordinate {
            let userPoint = MKMapPoint(user)
            let tiny = MKMapRect(x: userPoint.x, y: userPoint.y, width: 1, height: 1)
            rect = rect.union(tiny)
        }

        guard !rect.isNull else { return }
        let padded = rect.insetBy(dx: -rect.size.width * 0.35 - 800, dy: -rect.size.height * 0.35 - 800)
        position = .rect(padded)
        hasAutoFramed = true
    }

    private func openCollectionPoint(_ job: BottleJob) {
        position = .region(
            MKCoordinateRegion(
                center: job.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
        selectedJob = nil
        DispatchQueue.main.async {
            selectedJob = job
        }
    }

    private func openPendingCollectionPointIfPossible() {
        guard let postId = dataService.pendingCollectionPointID else { return }
        guard let match = jobs.first(where: { $0.id == postId }) else { return }

        selectedJob = match
        position = .region(
            MKCoordinateRegion(
                center: match.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
        dataService.clearPendingCollectionPointOpen(postId)
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color.brandGreen)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MapView()
        .environmentObject(LocationService())
        .environmentObject(DataService.shared)
}
