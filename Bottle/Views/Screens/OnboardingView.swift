//
//  OnboardingView.swift
//  bottlr
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var step: Int = 0
    @State private var selectedType: UserType = .collector
    @State private var name: String = ""
    @State private var isRequestingPermissions = false
    
    private let introPages: [(icon: String, title: String, body: String)] = [
        (
            icon: "leaf.circle.fill",
            title: "Turn Bottles Into Impact",
            body: "Every verified pickup keeps recyclable bottles out of landfills and contributes to cleaner neighborhoods."
        ),
        (
            icon: "person.2.fill",
            title: "Community-Powered Recycling",
            body: "Hosts post collection points, collectors claim and verify pickups, and everyone tracks environmental progress."
        ),
        (
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Real CO₂ Savings",
            body: "Watch your bottles diverted and climate impact update in real time across your profile and city stats."
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                if step < introPages.count {
                    TabView(selection: $step) {
                        ForEach(Array(introPages.enumerated()), id: \.offset) { index, page in
                            VStack(spacing: 20) {
                                Spacer(minLength: 20)
                                ZStack {
                                    Circle()
                                        .fill(Color.brandBlueLight.opacity(0.18))
                                        .frame(width: 170, height: 170)
                                    Image(systemName: page.icon)
                                        .font(.system(size: 70))
                                        .foregroundColor(.brandGreen)
                                }
                                Text(page.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                Text(page.body)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 28)
                                Spacer()
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    
                    Button("Continue") {
                        withAnimation(.easeInOut) {
                            step = min(step + 1, introPages.count)
                        }
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    Spacer(minLength: 10)
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandBlueLight.opacity(0.34), Color.brandGreen.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 146, height: 146)
                            .shadow(color: Color.brandBlueLight.opacity(0.25), radius: 14, y: 6)

                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 122, height: 122)

                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                    }
                    
                    Text("Choose your role")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You can change this later in your profile settings.")
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
                            .accessibilityLabel("Enter your display name")
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        roleButton(
                            title: "Collector",
                            subtitle: "Claim nearby posts and verify pickups",
                            icon: "figure.walk",
                            selected: selectedType == .collector
                        ) {
                            selectedType = .collector
                        }
                        roleButton(
                            title: "Host",
                            subtitle: "Post bottle collection points for pickup",
                            icon: "house",
                            selected: selectedType == .donor
                        ) {
                            selectedType = .donor
                        }
                    }
                    .padding(.horizontal)
                    
                    Button {
                        completeSetup()
                    } label: {
                        HStack {
                            if isRequestingPermissions {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Get Started")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRequestingPermissions)
                    .padding(.horizontal)
                    Spacer()
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }
    
    @ViewBuilder
    private func roleButton(title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(selected ? .white.opacity(0.9) : .secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(selected ? Color.brandGreen : Color(.secondarySystemBackground))
            .foregroundColor(selected ? .white : .primary)
            .cornerRadius(12)
        }
    }

    private func completeSetup() {
        isRequestingPermissions = true
        AppNotificationService.shared.requestPermissionIfNeeded()
        authService.completeOnboarding(name: name, userType: selectedType)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isRequestingPermissions = false
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService())
}
