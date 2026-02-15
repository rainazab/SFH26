//
//  WelcomeView.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var showWelcome: Bool
    @State private var currentPage = 0
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    let pages: [(icon: String, title: String, subtitle: String, color: String)] = [
        (
            icon: "waterbottle.fill",
            title: "bottlr: Bottles Into Impact",
            subtitle: "Coordinate bottle pickups fast and keep recyclable material out of landfill.",
            color: "7CCF73"
        ),
        (
            icon: "map.fill",
            title: "Find Posts Near You",
            subtitle: "See all available bottles on an interactive map. Claim the best ones first.",
            color: "3F56AE"
        ),
        (
            icon: "checkmark.seal.fill",
            title: "Track Verified Drop-Offs",
            subtitle: "Monitor completed pickups, bottle counts, and verified climate outcomes.",
            color: "78B6F6"
        ),
        (
            icon: "heart.circle.fill",
            title: "Make a Difference",
            subtitle: "Join 150,000 collectors creating a cleaner, more sustainable California.",
            color: "3F56AE"
        )
    ]
    
    var body: some View {
        ZStack {
            // Dynamic gradient background
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: pages[currentPage].color).opacity(0.4), Color.black]
                    : [Color(hex: pages[currentPage].color).opacity(0.2), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color(hex: pages[currentPage].color) : Color.gray.opacity(0.3))
                            .frame(width: currentPage == index ? 30 : 8, height: 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 60)
                
                // Main content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPage(page: pages[index], isAnimating: $isAnimating)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { oldValue, newValue in
                    HapticManager.shared.selection()
                    isAnimating = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isAnimating = true
                        }
                    }
                }
                
                // Bottom buttons
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        // Final page - Show role selection
                        VStack(spacing: 12) {
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                withAnimation(.spring()) {
                                    showWelcome = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: "figure.walk")
                                    Text("I'm a Collector")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.brandGreen, Color.brandBlueDark, Color.brandBlueLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                withAnimation(.spring()) {
                                    showWelcome = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                    Text("I Want to Donate")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemBackground))
                                .foregroundColor(Color.brandGreen)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.brandGreen, lineWidth: 2)
                                )
                            }
                        }
                    } else {
                        Button(action: {
                            HapticManager.shared.selection()
                            withAnimation(.spring()) {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: pages[currentPage].color), Color(hex: pages[currentPage].color).opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        
                        Button("Skip") {
                            HapticManager.shared.impact(.light)
                            withAnimation(.spring()) {
                                showWelcome = false
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct OnboardingPage: View {
    let page: (icon: String, title: String, subtitle: String, color: String)
    @Binding var isAnimating: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated icon with pulsing effect
            ZStack {
                Circle()
                    .fill(Color(hex: page.color).opacity(0.2))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                Circle()
                    .fill(Color(hex: page.color).opacity(0.3))
                    .frame(width: 150, height: 150)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: page.icon)
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: page.color))
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)
            }
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimating)
                
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimating)
            }
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeView(showWelcome: .constant(true))
}

#Preview("Dark Mode") {
    WelcomeView(showWelcome: .constant(true))
        .preferredColorScheme(.dark)
}
