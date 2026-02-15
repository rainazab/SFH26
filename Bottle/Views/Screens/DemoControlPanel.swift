//
//  DemoControlPanel.swift
//  Bottle
//

import SwiftUI

struct DemoControlPanel: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var mockData = MockDataService.shared
    
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
                        Text("Active Job")
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
                    if mockData.currentUser.type == .donor {
                        NavigationLink("Create Listing", destination: DonorCreateJobView())
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
}
