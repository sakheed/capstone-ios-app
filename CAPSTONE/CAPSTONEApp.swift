//
//  CAPSTONEApp.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 2/11/25.
//

import SwiftUI
import RealmSwift
import Foundation

// Main application entry point for the CAPSTONE SwiftUI app
@main
struct CAPSTONEApp: SwiftUI.App {
    // Shared data store for detection results, injected into the environment
    @StateObject private var detectionStore = DetectionDataStore()

    // Define the app's main scene and initial view hierarchy
    var body: some Scene {
        WindowGroup {
            // Root view with access to the shared detection store
            ContentView()
                .environmentObject(detectionStore)
        }
    }
}
