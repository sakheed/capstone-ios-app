import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    // The latest known location
    @Published var currentLocation: CLLocation?

    // Authorization status to observe changes in the UI if needed
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        
        // Set up the location manager
        locationManager.delegate = self
        
        // Configure for best accuracy
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Configure background updates

        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Request "Always" authorization

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

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Keep track of the current authorization status
        DispatchQueue.main.async {
            self.authorizationStatus = status
            

            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.locationManager.startUpdatingLocation()
            } else {
                // Handle other states (.denied, .restricted, etc.) as needed
                self.locationManager.stopUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Update the published property with the most recent location
        guard let latestLocation = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = latestLocation
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors
        print("Location update failed with error: \(error)")
    }
}
