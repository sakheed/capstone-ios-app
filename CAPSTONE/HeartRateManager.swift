//
//  HeartRateManager.swift
//  CAPSTONE
//
//  Created by Aman Singh on 4/8/25.
//

import HealthKit
import Foundation
import Combine

class HeartRateManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    // Published property to update the UI when the heart rate is retrieved
    @Published var heartRate: Double?
    
    // Request permission and start querying for heart rate data
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("Health data not available on this device")
            return
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Heart Rate Type is no longer available in HealthKit")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { [weak self] success, error in
            if success {
                self?.startObservingHeartRateData()
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    // Query heart rate using HKAnchoredObjectQuery
    private func startObservingHeartRateData() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(type: heartRateType,
                                          predicate: nil,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, newAnchor, error in
            if let samples = samples as? [HKQuantitySample] {
                self?.handleHeartRateSamples(samples)
            }
        }
        
        // Update handler for live data updates
        query.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            if let samples = samples as? [HKQuantitySample] {
                self?.handleHeartRateSamples(samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    // Process the heart rate samples and update the published heartRate
    private func handleHeartRateSamples(_ samples: [HKQuantitySample]) {
        // Optionally, filter samples to only include those that come from an Apple Watch.
        // Adjust the string check as needed based on the actual source name of the Apple Watch.
        let appleWatchSamples = samples.filter { sample in
            guard let sourceName = sample.sourceRevision.source.name.lowercased() as String? else {
                return false
            }
            return sourceName.contains("watch")
        }
        
        // If no Apple Watch samples are found, do nothing.
        guard let sample = appleWatchSamples.last else { return }
        
        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let heartRateValue = sample.quantity.doubleValue(for: heartRateUnit)
        
        DispatchQueue.main.async {
            self.heartRate = heartRateValue
        }
    }

}
