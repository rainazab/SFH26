//
//  FlipApp.swift
//  Flip
//
//  Created by Raina Zab on 2/13/26.
//

import SwiftUI

@main
struct FlipApp: App {
    @State private var showWelcome = true
    
    var body: some Scene {
        WindowGroup {
            if showWelcome {
                WelcomeView(showWelcome: $showWelcome)
            } else {
                MainTabView()
            }
        }
    }
}
