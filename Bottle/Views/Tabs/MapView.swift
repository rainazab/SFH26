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
    @StateObject private var dataService = DataService.shared
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    @State private var selectedJob: BottleJob?
    @State private var showingJobDetail = false
    @State private var isPulsing = true
    @State private var todayEarnings: Double = 0
    @State private var showNewJobToast = false

    private var jobs: [BottleJob] { dataService.availableJobs }
    
    var nearestHighValueJob: BottleJob? {
        jobs.filter({ $0.estimatedValue > 30 }).min(by: { ($0.distance ?? 0) < ($1.distance ?? 0) })
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
                            showingJobDetail = true
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
                                    Text("$\(Int(job.estimatedValue))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            // Top Header
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nearby Posts")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(jobs.count) posts nearby")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Filter Button
                    Button(action: {}) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.brandGreen)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.1), radius: 8)
                .padding()
                
                Spacer()
            }
            
            // Bottom Stats Card
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TODAY'S EARNINGS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Animated counter
                            AnimatedNumber(value: todayEarnings, format: "%.0f")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color.brandGreen)
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
                    
                    // Urgency alert for nearby high-value job
                    if let highValueJob = nearestHighValueJob {
                        Divider()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.accentOrange)
                            Text("High-value post \(String(format: "%.1f", highValueJob.distance ?? 0)) mi away!")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                selectedJob = highValueJob
                                showingJobDetail = true
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
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentOrange.opacity(0.15))
                        .cornerRadius(10)
                    } else {
                        Divider()
                        
                        // Quick Stats
                        HStack(spacing: 20) {
                            StatBadge(icon: "checkmark.circle.fill", value: "8", label: "Completed")
                            StatBadge(icon: "clock.fill", value: "3", label: "Pending")
                            StatBadge(icon: "arrow.up.circle.fill", value: "4.8", label: "Rating")
                        }
                    }
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
                        Text("New post nearby!")
                            .fontWeight(.semibold)
                        Spacer()
                        Button("View") {
                            HapticManager.shared.impact(.light)
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
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            showNewJobToast = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingJobDetail) {
            if let job = selectedJob {
                JobDetailView(job: job)
                    .environmentObject(locationService)
            }
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
            todayEarnings = Double(dataService.completedJobs.filter {
                Calendar.current.isDateInToday($0.date)
            }.reduce(0) { $0 + $1.bottleCount })
            // Simulate new job appearing for demo
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation(.spring()) {
                    showNewJobToast = true
                    HapticManager.shared.notification(.success)
                }
            }
        }
        .onChange(of: locationService.userLocation) { _, location in
            if let location {
                dataService.updateJobDistances(from: location.coordinate)
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                position = .region(region)
            }
        }
    }
    
    func tierColor(_ tier: JobTier) -> Color {
        switch tier {
        case .residential: return .tierResidential
        case .bulk: return .tierBulk
        case .commercial: return .tierCommercial
        }
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
}
