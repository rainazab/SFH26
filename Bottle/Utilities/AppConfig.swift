//
//  AppConfig.swift
//  Bottle
//

import Foundation

enum AppConfig {
    private static let mockModeKey = "app.useMockData"
    private static let aiEnabledKey = "app.aiVerificationEnabled"
    private static let aiUseRealModelKey = "app.aiUseRealModel"
    private static let climateAnimationKey = "app.climateAnimationEnabled"

    static var useMockData: Bool {
        get { UserDefaults.standard.bool(forKey: mockModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: mockModeKey) }
    }

    static var aiVerificationEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: aiEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: aiEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: aiEnabledKey) }
    }

    static var aiUseRealModel: Bool {
        get { UserDefaults.standard.bool(forKey: aiUseRealModelKey) }
        set { UserDefaults.standard.set(newValue, forKey: aiUseRealModelKey) }
    }

    static var climateAnimationEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: climateAnimationKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: climateAnimationKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: climateAnimationKey) }
    }
}
