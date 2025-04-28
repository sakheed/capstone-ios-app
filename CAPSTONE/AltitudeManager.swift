//
//  AltitudeManager.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 4/28/25.
//


import CoreMotion

class AltitudeManager: ObservableObject {
  private let altimeter = CMAltimeter()
  @Published var relativeAltitude: Double? = nil

  func start() {
    guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
    altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
      if let err = error {
        print("Altimeter error:", err)
      } else if let d = data {
        // d.relativeAltitude is in meters (as NSNumber)
        self.relativeAltitude = d.relativeAltitude.doubleValue
      }
    }
  }

  func stop() {
    altimeter.stopRelativeAltitudeUpdates()
  }
}
