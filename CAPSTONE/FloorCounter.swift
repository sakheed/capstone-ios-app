//
//  FloorCounter.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 4/28/25.
//

import CoreMotion

// FloorCounter publishes net floors climbed or descended via CMPedometer
class FloorCounter: ObservableObject {
    // Pedometer instance for tracking floor data
    private let pedometer = CMPedometer()
    
    // Published value representing floors ascended minus floors descended
    @Published var floorDelta: Double? = 0.0

    // Begin receiving floor count updates from the current date
    func start() {
        // Only proceed if floor counting is available on this device
        guard CMPedometer.isFloorCountingAvailable() else { return }
        
        // Start pedometer updates with a handler for new data
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            // Safely unwrap self and data, otherwise exit
            guard let self = self, let d = data else { return }

            // Convert NSNumber floor counts to Double values
            let asc  = d.floorsAscended?.doubleValue   ?? 0.0
            let desc = d.floorsDescended?.doubleValue ?? 0.0

            // Compute net floor delta and publish on main queue
            DispatchQueue.main.async {
                self.floorDelta = asc - desc
            }
        }
    }

    // Stop receiving pedometer updates
    func stop() {
        pedometer.stopUpdates()
    }
}
