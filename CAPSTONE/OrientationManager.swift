//
//  OrientationManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 3/17/25.
//
// OrientationManager provides device orientation data via Core Motion

import Foundation
import CoreMotion
import SwiftUI

// ObservableObject that publishes device attitude updates
class OrientationManager: ObservableObject {
    // Core Motion manager for accessing device motion data
    private let motionManager = CMMotionManager()
    
    // Current device attitude published to any SwiftUI views
    @Published var attitude: CMAttitude?
    
    // Start motion updates if available
    init() {
        // Check for device motion availability
        if motionManager.isDeviceMotionAvailable {
            // Set the frequency of motion updates (10 per second)
            motionManager.deviceMotionUpdateInterval = 0.1
            // Begin receiving device motion updates on main queue
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
                // Assign attitude when valid data is received
                if let data = data {
                    self?.attitude = data.attitude
                }
            }
        } else {
            // Inform if device motion is unsupported
            print("Device motion is not available.")
        }
    }
    
    // Clean up motion updates when this manager is deallocated
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
