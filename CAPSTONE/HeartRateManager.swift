//
//  HeartRateManager.swift
//  CAPSTONE
//
//  Created by Aman Singh on 4/8/25.
//

import HealthKit
import Foundation
import Combine

// HeartRateManager handles HealthKit authorization and heart rate data sampling
class HeartRateManager: ObservableObject {
    // HealthKit store for reading heart rate data
    private let healthStore = HKHealthStore()
    
    // Published heart rate value in beats per minute
    @Published var heartRate: Double?
    
    // Request permission to read heart rate data and start observing if granted
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
                self?.startObservingHeartRateData() // Begin live data updates
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    // Set up anchored query to receive existing and new heart rate samples
    private func startObservingHeartRateData() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(type: heartRateType,
                                          predicate: nil,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            if let samples = samples as? [HKQuantitySample] {
                self?.handleHeartRateSamples(samples) // Process initial samples
            }
        }
        
        // Continuously receive updates for new heart rate samples
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            if let samples = samples as? [HKQuantitySample] {
                self?.handleHeartRateSamples(samples)
            }
        }
        
        healthStore.execute(query) // Execute the query
    }
    
    // Filter, convert, and publish the most recent Apple Watch heart rate sample
    private func handleHeartRateSamples(_ samples: [HKQuantitySample]) {
        // Keep only samples originating from an Apple Watch
        let appleWatchSamples = samples.filter { sample in
            sample.sourceRevision.source.name.lowercased().contains("watch")
        }
        
        guard let sample = appleWatchSamples.last else { return }
        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let heartRateValue = sample.quantity.doubleValue(for: heartRateUnit)
        
        DispatchQueue.main.async {
            // Update published property
            self.heartRate = heartRateValue
        }
    }
}
