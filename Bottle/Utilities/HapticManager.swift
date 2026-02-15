//
//  HapticManager.swift
//  Bottle
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    func success() {
        notification(.success)
    }

    func error() {
        notification(.error)
    }
}

#else

// Fallback for non-UIKit platforms (macOS, etc.)
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(_ style: Int) {}
    func notification(_ type: Int) {}
    func selection() {}
    func success() {}
    func error() {}
}

#endif
