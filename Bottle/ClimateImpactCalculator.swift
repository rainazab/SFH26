//
//  ClimateImpactCalculator.swift
//  Bottle
//
//  Climate Impact Tracking (for Climate Action Track)
//

import Foundation

struct ClimateImpactCalculator {
    // MARK: - Research-Based Constants
    // California CRV Program Data + EPA Statistics
    
    static let co2PerBottle: Double = 0.045  // kg CO₂ saved per bottle recycled
    static let co2PerTree: Double = 22.0     // kg CO₂ absorbed per tree per year (EPA)
    static let waterPerBottle: Double = 0.5  // gallons water saved (PET bottle production)
    static let wastePerBottle: Double = 0.025  // kg waste avoided per bottle
    
    // MARK: - Primary Calculations
    
    static func calculateImpact(bottles: Int) -> ClimateImpact {
        let co2Saved = Double(bottles) * co2PerBottle
        let treesEquivalent = Int(co2Saved / co2PerTree)
        let waterSaved = Double(bottles) * waterPerBottle
        let wasteReduced = Double(bottles) * wastePerBottle
        
        // Fun comparisons for users
        let daysCarRemoved = calculateCarDays(co2: co2Saved)
        let homePowerDays = calculateHomeDays(co2: co2Saved)
        
        return ClimateImpact(
            bottles: bottles,
            co2SavedKg: co2Saved,
            treesEquivalent: treesEquivalent,
            waterSavedGallons: waterSaved,
            wasteReducedKg: wasteReduced,
            daysCarRemoved: daysCarRemoved,
            daysHomePowered: homePowerDays
        )
    }
    
    // MARK: - Comparison Calculations
    
    // Compare to car emissions
    static func calculateCarDays(co2: Double) -> Int {
        // Average passenger car: 411g CO₂/mile, 13,500 miles/year
        let dailyCarEmissions = (411.0 * 13500) / 365 / 1000  // kg/day
        return Int(co2 / dailyCarEmissions)
    }
    
    // Compare to home energy use
    static func calculateHomeDays(co2: Double) -> Int {
        // Average US home: 4.5 metric tons CO₂/year
        let dailyHomeEmissions = 4500 / 365  // kg/day
        return Int(co2 / dailyHomeEmissions)
    }
    
    // MARK: - Aggregate Calculations (for leaderboards)
    
    static func calculateCommunityImpact(totalBottles: Int) -> CommunityImpact {
        let impact = calculateImpact(bottles: totalBottles)
        
        return CommunityImpact(
            individualImpact: impact,
            communitySize: calculateCommunitySize(bottles: totalBottles),
            globalRanking: calculateGlobalRanking(bottles: totalBottles),
            nextMilestone: calculateNextMilestone(bottles: totalBottles)
        )
    }
    
    private static func calculateCommunitySize(bottles: Int) -> Int {
        // Estimate number of households contributing
        return bottles / 30  // Average household: 30 bottles/month
    }
    
    private static func calculateGlobalRanking(bottles: Int) -> String {
        if bottles > 10000 { return "Top 1%" }
        if bottles > 5000 { return "Top 5%" }
        if bottles > 1000 { return "Top 10%" }
        if bottles > 500 { return "Top 25%" }
        return "Top 50%"
    }
    
    private static func calculateNextMilestone(bottles: Int) -> Milestone {
        let milestones = [100, 500, 1000, 5000, 10000]
        let next = milestones.first(where: { $0 > bottles }) ?? bottles + 1000
        
        let nextImpact = calculateImpact(bottles: next)
        
        return Milestone(
            bottles: next,
            progress: Double(bottles) / Double(next),
            reward: determineMilestoneReward(bottles: next),
            impactPreview: nextImpact
        )
    }
    
    private static func determineMilestoneReward(bottles: Int) -> String {
        switch bottles {
        case 100: return "🥉 Bronze Recycler Badge"
        case 500: return "🥈 Silver Guardian Badge"
        case 1000: return "🥇 Gold Champion Badge"
        case 5000: return "💎 Diamond Hero Badge"
        case 10000: return "🏆 Platinum Legend Badge + Featured Profile"
        default: return "🎖️ Special Badge"
        }
    }
}

// MARK: - Impact Models

struct ClimateImpact: Codable {
    let bottles: Int
    let co2SavedKg: Double
    let treesEquivalent: Int
    let waterSavedGallons: Double
    let wasteReducedKg: Double
    let daysCarRemoved: Int
    let daysHomePowered: Int
    
    // Human-readable description for sharing
    var description: String {
        """
        🌍 Climate Impact Summary:
        • \(bottles) bottles recycled
        • \(String(format: "%.1f", co2SavedKg))kg CO₂ saved
        • Equivalent to \(treesEquivalent) trees for a year
        • \(String(format: "%.0f", waterSavedGallons)) gallons water conserved
        • Like removing a car from the road for \(daysCarRemoved) days
        """
    }
    
    // Short version for social sharing
    var shareText: String {
        "I've saved \(String(format: "%.1f", co2SavedKg))kg of CO₂ by recycling \(bottles) bottles with @BottleApp! 🌍♻️"
    }
}

struct CommunityImpact {
    let individualImpact: ClimateImpact
    let communitySize: Int
    let globalRanking: String
    let nextMilestone: Milestone
}

struct Milestone {
    let bottles: Int
    let progress: Double
    let reward: String
    let impactPreview: ClimateImpact
}
