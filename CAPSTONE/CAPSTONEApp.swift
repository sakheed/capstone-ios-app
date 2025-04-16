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
    init() {
            // 👇 Add this block to force a new Realm file per launch
            let uniqueFileName = "default_\(UUID().uuidString.prefix(6)).realm"
            if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let newRealmURL = documentsDir.appendingPathComponent(uniqueFileName)
                Realm.Configuration.defaultConfiguration.fileURL = newRealmURL
                print("📂 New Realm path set to: \(newRealmURL.path)")
            }
        }
    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(detectionStore)
        }
    }
}
