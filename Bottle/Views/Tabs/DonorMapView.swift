//
//  DonorMapView.swift
//  Bottle
//
//  Read-only live map for donors.
//

import SwiftUI
import MapKit

struct DonorMapView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var dataService: DataService
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                UserAnnotation()
                ForEach(dataService.myPostedJobs) { post in
                    Marker(post.title, coordinate: post.coordinate)
                        .tint(Color.brandGreen)
                }
            }
            .ignoresSafeArea()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("View All Posts")
                        .font(.headline)
                    Text("\(dataService.myPostedJobs.count) posts you created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding()
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let coordinate = locationService.userLocation?.coordinate {
                position = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            }
        }
    }
}

#Preview {
    DonorMapView()
        .environmentObject(LocationService())
        .environmentObject(DataService.shared)
}
