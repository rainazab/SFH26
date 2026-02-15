//
//  Extensions.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

// MARK: - View Extensions for Styling
extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
    }
    
    func floatingCardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.08), radius: 3, y: 2)
            .shadow(color: Color.black.opacity(0.15), radius: 15, y: 8)
    }
    
    func pressableCardStyle(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255,
                            (int >> 16) & 0xFF,
                            (int >> 8) & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF,
                            (int >> 16) & 0xFF,
                            (int >> 8) & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // Primary brand colors with depth
    static let brandGreen = Color(hex: "00C853")
    static let brandGreenLight = Color(hex: "00E676")
    static let brandGreenDark = Color(hex: "00A843")
    
    // Tier colors - more vibrant
    static let tierResidential = Color(hex: "4CAF50")
    static let tierBulk = Color(hex: "2196F3")
    static let tierCommercial = Color(hex: "9C27B0")
    
    // Accent colors - more punch
    static let accentOrange = Color(hex: "FF6B35")
    static let accentGold = Color(hex: "FFB800")
    static let accentRed = Color(hex: "FF6B6B")
    
    // Gradients for premium feel
    static func brandGradient() -> LinearGradient {
        LinearGradient(
            colors: [Color.brandGreen, Color.brandGreenLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func tierGradient(_ tier: JobTier) -> LinearGradient {
        switch tier {
        case .residential:
            return LinearGradient(colors: [Color.tierResidential, Color(hex: "66BB6A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bulk:
            return LinearGradient(colors: [Color.tierBulk, Color(hex: "42A5F5")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .commercial:
            return LinearGradient(colors: [Color.tierCommercial, Color(hex: "AB47BC")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Font Extensions
extension Font {
    static let heroTitle = Font.system(size: 48, weight: .bold)
    static let displayTitle = Font.system(size: 36, weight: .bold)
    static let sectionTitle = Font.system(size: 24, weight: .bold)
    static let cardTitle = Font.system(size: 18, weight: .semibold)
    static let bodyText = Font.system(size: 16, weight: .regular)
    static let captionText = Font.system(size: 13, weight: .medium)
    static let captionSmall = Font.system(size: 11, weight: .regular)
}
