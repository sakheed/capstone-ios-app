//
//  GyroscopeManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 3/17/25.
//

import Foundation
import CoreMotion
import SwiftUI

// GyroscopeManager publishes device rotation rates using Core Motion
class GyroscopeManager: ObservableObject {
    // Core Motion manager instance for gyroscope data
    private let motionManager = CMMotionManager()
    
    // Published rotation rate in radians per second
    @Published var rotationRate: CMRotationRate?
    
    // Initialize and start gyroscope updates
    init() {
        startGyroUpdates()
    }
    
    // Configure and begin receiving gyroscope data
    func startGyroUpdates() {
        // Check for gyroscope availability
        if motionManager.isGyroAvailable {
            // Set update interval to 10 times per second
            motionManager.gyroUpdateInterval = 0.1
            // Start updates on main queue with error handling
            motionManager.startGyroUpdates(to: .main) { [weak self] data, error in
                guard let data = data else {
                    if let error = error {
                        // Log any errors from the gyroscope
                        print("Gyroscope error: \(error.localizedDescription)")
                    }
                    return
                }
                // Publish the latest rotation rate
                self?.rotationRate = data.rotationRate
            }
        } else {
            // Notify when gyroscope is unsupported
            print("Gyroscope is not available on this device.")
        }
    }
    
    // Stop receiving gyroscope updates
    func stopGyroUpdates() {
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
        }
    }
}
