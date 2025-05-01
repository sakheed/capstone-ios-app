//
//  AltitudeManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 4/28/25.
//

import CoreMotion

// AltitudeManager provides relative altitude data using CMAltimeter
class AltitudeManager: ObservableObject {
    // Altimeter instance for capturing altitude updates
    private let altimeter = CMAltimeter()
    
    // Published relative altitude in meters
    @Published var relativeAltitude: Double? = nil

    // Begin relative altitude updates if the sensor is available
    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
            if let err = error {
                // Log errors encountered during altitude updates
                print("Altimeter error:", err)
            } else if let d = data {
                // Publish the latest relative altitude value
                self.relativeAltitude = d.relativeAltitude.doubleValue
            }
        }
    }

    // Stop receiving relative altitude updates
    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
    }
}
