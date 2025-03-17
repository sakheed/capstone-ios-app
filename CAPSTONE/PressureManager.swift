//
//  PressureManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 3/17/25.
//

import Foundation
import CoreMotion
import SwiftUI

class PressureManager: ObservableObject {
    private let altimeter = CMAltimeter()
    @Published var pressure: Double? = nil
    
    init() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                if let data = data, error == nil {
                    // Convert kPa to hPa (1 kPa = 10 hPa)
                    DispatchQueue.main.async {
                        self?.pressure = data.pressure.doubleValue * 10.0
                    }
                } else {
                    print("Error reading altimeter data: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        } else {
            print("Altimeter is not available on this device.")
        }
    }
}

