//
//  DemoControlPanel.swift
//  Bottle
//

import SwiftUI

struct DemoControlPanel: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var mockData = MockDataService.shared
    @EnvironmentObject var dataService: DataService
    @State private var useMockData = AppConfig.useMockData
    @State private var aiEnabled = AppConfig.aiVerificationEnabled
    @State private var climateAnimations = AppConfig.climateAnimationEnabled
    
    var body: some View {
        NavigationView {
            List {
                Section("Switch User") {
                    ForEach(Array(mockData.allUsers.enumerated()), id: \.element.id) { index, user in
                        Button {
                            mockData.switchUser(to: index)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name).foregroundColor(.primary)
                                    Text(user.type.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if user.id == mockData.currentUser.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                Section("Status") {
                    HStack {
                        Text("Active Post")
                        Spacer()
                        Text(mockData.hasActiveJob ? "Yes" : "No")
                    }
                    HStack {
                        Text("Can Claim New")
                        Spacer()
                        Text(mockData.canClaimNewJob ? "Yes" : "No")
                    }
                }
                
                Section("Actions") {
                    Button("Reset Demo") {
                        mockData.resetDemo()
                    }
                    Button("Inject High-Value Post") {
                        Task { await dataService.injectHighValueDemoJob() }
                    }
                    if mockData.currentUser.type == .donor {
                        NavigationLink("Create Listing", destination: DonorCreateJobView())
                    }
                }

                Section("Backend") {
                    Toggle("Use Mock Data", isOn: $useMockData)
                        .onChange(of: useMockData) { _, value in
                            AppConfig.useMockData = value
                            dataService.refreshBackendMode()
                        }
                    Text("Current: \(dataService.backendStatus)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Demo Feature Toggles") {
                    Toggle("AI Verification Enabled", isOn: $aiEnabled)
                        .onChange(of: aiEnabled) { _, value in
                            AppConfig.aiVerificationEnabled = value
                        }
                    Toggle("Climate Animations", isOn: $climateAnimations)
                        .onChange(of: climateAnimations) { _, value in
                            AppConfig.climateAnimationEnabled = value
                        }
                }
            }
            .navigationTitle("Demo Controls")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DemoControlPanel()
        .environmentObject(DataService.shared)
}
