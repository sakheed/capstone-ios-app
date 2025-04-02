//
//  CAPSTONEApp.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 2/11/25.
//

import SwiftUI

@main
struct CAPSTONEApp: App {
    @StateObject private var detectionStore = DetectionDataStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(detectionStore) 
        }
    }
}
