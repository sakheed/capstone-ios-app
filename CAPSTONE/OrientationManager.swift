//
//  OrientationManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 3/17/25.
//

import Foundation
import CoreMotion
import SwiftUI

class OrientationManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var attitude: CMAttitude?
    
    init() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
                if let data = data {
                    self?.attitude = data.attitude
                }
            }
        } else {
            print("Device motion is not available.")
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
