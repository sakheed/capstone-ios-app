//
//  GyroscopeManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 3/17/25.
//

import Foundation
import CoreMotion
import SwiftUI

class GyroscopeManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var rotationRate: CMRotationRate?
    
    init() {
        startGyroUpdates()
    }
    
    func startGyroUpdates() {
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data else {
                    if let error = error {
                        print("Gyroscope error: \(error.localizedDescription)")
                    }
                    return
                }
                self?.rotationRate = data.rotationRate
            }
        } else {
            print("Gyroscope is not available on this device.")
        }
    }
    
    func stopGyroUpdates() {
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
        }
    }
}

