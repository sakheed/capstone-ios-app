//
//  FloorCounter.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 4/28/25.
//


import CoreMotion

class FloorCounter: ObservableObject {
    private let pedometer = CMPedometer()
    @Published var floorDelta: Double? = 0.0   

    func start() {
        guard CMPedometer.isFloorCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self = self, let d = data else { return }

            // extract as Doubles (NSNumber → Double)
            let asc  = d.floorsAscended?.doubleValue   ?? 0.0
            let desc = d.floorsDescended?.doubleValue ?? 0.0

            // update on main queue
            DispatchQueue.main.async {
                self.floorDelta = asc - desc
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}
