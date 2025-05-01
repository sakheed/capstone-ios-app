//
//  PressureManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 3/17/25.
//

import Foundation
import CoreMotion
import SwiftUI

// PressureManager uses Core Motion altimeter to track atmospheric pressure
class PressureManager: ObservableObject {
    // Altimeter instance for relative altitude and pressure data
    private let altimeter = CMAltimeter()
    
    // Published pressure value in hectopascals (hPa)
    @Published var pressure: Double? = nil
    
    // Initialize and start altimeter updates if available
    init() {
        // Verify altimeter support on this device
        if CMAltimeter.isRelativeAltitudeAvailable() {
            // Begin receiving altitude data on main queue
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                if let data = data, error == nil {
                    // Convert pressure from kPa to hPa and update published value
                    DispatchQueue.main.async {
                        self?.pressure = data.pressure.doubleValue * 10.0
                    }
                } else {
                    // Log any errors encountered during update
                    print("Error reading altimeter data: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        } else {
            // Notify if altimeter functionality is unavailable
            print("Altimeter is not available on this device.")
        }
    }
}
