//
//  CAPSTONEApp.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 2/11/25.
//

import SwiftUI
import RealmSwift
import Foundation

@main
struct CAPSTONEApp: SwiftUI.App {
    @StateObject private var detectionStore = DetectionDataStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(detectionStore)
        }
    }
}
