import Foundation
import CoreLocation
import Combine

// LocationManager provides continuous location updates and authorization tracking
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Core Location manager instance
    private let locationManager = CLLocationManager()

    // The latest known location
    @Published var currentLocation: CLLocation?

    // Authorization status to observe changes in the UI if needed
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Initialize and configure CLLocationManager
    override init() {
        super.init()
        
        // Assign delegate for callback handling
        locationManager.delegate = self
        
        // Set highest possible accuracy
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Request permission to access location always
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Start/Stop Updates

    /// Begin continuous location updates
    func startUpdating() {
        locationManager.startUpdatingLocation()
    }
    
    /// Stop location updates
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    // Handle changes in authorization status
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            // Update published authorization status
            self.authorizationStatus = status

            // Start or stop updates based on permission
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.locationManager.startUpdatingLocation()
            } else {
                self.locationManager.stopUpdatingLocation()
            }
        }
    }

    // Receive new location data and publish it
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = latestLocation
        }
    }

    // Log any errors encountered during location updates
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed with error: \(error)")
    }
}
