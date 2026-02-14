//
//  AnimatedComponents.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

// MARK: - Animated Number Counter
struct AnimatedNumber: View {
    let value: Double
    let format: String
    let duration: Double
    
    @State private var displayValue: Double = 0
    
    init(value: Double, format: String = "$%.0f", duration: Double = 1.5) {
        self.value = value
        self.format = format
        self.duration = duration
    }
    
    var body: some View {
        Text(String(format: format, displayValue))
            .onAppear {
                animateCounter()
            }
            .onChange(of: value) { oldValue, newValue in
                animateToValue(newValue)
            }
    }
    
    private func animateCounter() {
        animateToValue(value)
    }
    
    private func animateToValue(_ targetValue: Double) {
        let steps = 30.0
        let increment = targetValue / steps
        let interval = duration / steps
        
        var currentStep = 0.0
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            displayValue = min(currentStep * increment, targetValue)
            
            if displayValue >= targetValue {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Loading Button
struct LoadingButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    let gradient: LinearGradient
    
    @State private var isLoading = false
    @State private var isPressed = false
    
    init(title: String, icon: String = "checkmark.circle.fill", gradient: LinearGradient = Color.brandGradient(), action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            isLoading = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                action()
                isLoading = false
                HapticManager.shared.notification(.success)
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: icon)
                }
                Text(isLoading ? "Processing..." : title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                if isLoading {
                    Color.gray
                } else {
                    gradient
                }
            }
            .foregroundColor(.white)
            .cornerRadius(15)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .disabled(isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Pulsing Badge
struct PulsingBadge: View {
    let text: String
    let color: Color
    
    @State private var isPulsing = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color)
            .cornerRadius(6)
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Shimmer Loading Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.5), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let buttonTitle = buttonTitle, let action = action {
                Button(action: action) {
                    Text(buttonTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.brandGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding(40)
    }
}
