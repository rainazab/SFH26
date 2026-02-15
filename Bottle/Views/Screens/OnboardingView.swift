//
//  OnboardingView.swift
//  bottlr
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var selectedType: UserType = .collector
    @State private var name: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)
                
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                
                Text("Welcome to bottlr")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Choose your role and finish setup")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter name", text: $name)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
                
                VStack(spacing: 12) {
                    Button {
                        selectedType = .collector
                    } label: {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("Collector")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedType == .collector ? Color.brandGreen : Color(.secondarySystemBackground))
                        .foregroundColor(selectedType == .collector ? .white : .primary)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        selectedType = .donor
                    } label: {
                        HStack {
                            Image(systemName: "house")
                            Text("Donor")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedType == .donor ? Color.brandGreen : Color(.secondarySystemBackground))
                        .foregroundColor(selectedType == .donor ? .white : .primary)
                        .cornerRadius(12)
                    }
                }
                
                Button {
                    authService.completeOnboarding(name: name, userType: selectedType)
                    hasCompletedOnboarding = true
                } label: {
                    Text("Get Started")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 6)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService())
}
