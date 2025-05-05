//
//  ContentView.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 2/11/25.
//
// Main content view coordinating splash, landing, and detection screens

import SwiftUI
import UIKit
import ZIPFoundation
import RealmSwift

// Model representing an exported file item for sharing
struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

// Wrapper to present UIActivityViewController for exports
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    // Create and configure the activity view controller
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    // Required by protocol; no updates needed
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// Splash screen with centered waveform icon
struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)  // Background
            Image(systemName: "waveform")          // Icon
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.blue)
        }
    }
}

// Landing page for QR registration and activation
struct LandingPage: View {
    @State private var isShowingScanner = false        // Controls QR sheet
    @State private var navigateToDetectionScreen = false  // Triggers navigation
    @State private var scannedURL: String?            // Stores scanned URL

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)        // Background

            VStack(spacing: 20) {
                Image(systemName: "waveform")            // Logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.blue)

                Text("Welcome to SignalQ!")             // Welcome text
                    .font(.title2)
                    .foregroundColor(.white)

                Link("Visit SignalQ Website", destination: URL(string: "https://www.signalq.com")!)  // Website link
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("SignalQ is a software-only signal intelligence platform that provides a low-cost, simple to incorporate, military-grade event detection capability that can leverage freely-associated mobile phones as sensors.")  // Description
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()

                Button(action: { isShowingScanner = true }) {  // QR Scanner button
                    Text("Register with QR Code")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .cornerRadius(50)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 50)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .frame(width: 300)
                .sheet(isPresented: $isShowingScanner) {
                    QRScannerView(isPresented: $isShowingScanner, scannedURL: $scannedURL)
                }

                Button(action: { navigateToDetectionScreen = true }) {  // Activate button
                    Text("Activate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0x4E/255, green: 0xAB/255, blue: 0xE2/255))
                        .cornerRadius(50)
                        .foregroundColor(Color(red: 0x25/255, green: 0x29/255, blue: 0x32/255))
                }
                .frame(width: 300)
                .background(
                    NavigationLink(
                        destination: DetectionScreen(),
                        isActive: $navigateToDetectionScreen,
                        label: { EmptyView() }
                    )
                    .hidden()
                )
            }
        }
        .onChange(of: scannedURL) { newURL, _ in  // Handle QR result
            if let urlString = newURL,
               let url = URL(string: urlString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                print("Error: Invalid QR Code URL")
            }
        }
    }
}

// Realm Database version of DetectionRecord
class DetectionRecordRealm: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var timestamp_UTCTime: Date // UTC time
    @Persisted var gpsLatitude_DEG: Double // degrees (°)
    @Persisted var gpsLongitude_DEG: Double // degrees (°)
    @Persisted var pressure_hPA: Double // hectopascals (hPa)
    @Persisted var orientationPitch_RAD: Double // radians (rad)
    @Persisted var orientationRoll_RAD: Double // radians (rad)
    @Persisted var orientationYaw_RAD: Double // radians (rad)
    @Persisted var gyroX_RAD_SEC: Double // radians per second (rad/s)
    @Persisted var gyroY_RAD_SEC: Double // radians per second (rad/s)
    @Persisted var gyroZ_RAD_SEC: Double // radians per second (rad/s)
    @Persisted var heartrate_BPM: Double // beats per minute (BPM)
    @Persisted var altitude_M: Double // altitude(M)
    @Persisted var relativeAltitude_M: Double // relative altitude (M)
    @Persisted var floorsClimbed_Floors: Double //floors climbed (floors)
    @Persisted var audioFilePath: String // file path string
    @Persisted var result: String
    @Persisted var confidence_PERCENT: Double
    @Persisted var uploadStatus: String
}

class DetectionDataStore: ObservableObject {
    @Published var records: [DetectionScreen.DetectionRecord] = []
}

class UploadRetryManager {

}

struct DetectionScreen: View {

    struct DetectionRecord: Identifiable {
        let id = UUID()
        let timestamp: Date
        let gpsLatitude: Double
        let gpsLongitude: Double
        let pressure: Double
        let orientationPitch: Double
        let orientationRoll: Double
        let orientationYaw: Double
        let gyroX: Double
        let gyroY: Double
        let gyroZ: Double
        let heartrate: Double
        let altitude: Double
        let relativeAltitude: Double
        let floorsClimbed: Double
        let audioFilePath: String
        let result: String
        let confidence: Double
        let uploadStatus: String
    }


    @State public var detectionRecords: [DetectionRecord] = []
    @EnvironmentObject var detectionStore: DetectionDataStore

    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var heartRateManager = HeartRateManager()

    // Built-in sensor managers:
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var gyroscopeManager = GyroscopeManager()
    @StateObject private var pressureManager = PressureManager()

    @StateObject private var altitudeManager  = AltitudeManager()
    @StateObject private var floorCounter = FloorCounter()

    @State private var exportItem: ExportItem? = nil

    @State public var timer: Timer?

    func startRetryLoop() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {[self] _ in self.retryFailedUploads()}
    }

    func stopRetryLoop() {
        timer?.invalidate()
        timer = nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                // Existing GPS status indicator and time display
                HStack {
                    Text("GPS: Active")
                        .font(.headline)
                        .foregroundColor(.green)
                    Spacer()
                    Text(Date(), style: .time)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.8))

                // Gunshot detection result box
                if let latestRecord = detectionStore.records.last, latestRecord.result.lowercased() == "gunshot" {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("🔫 Gunshot Detected!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(String(format: "Confidence: %.1f%%", latestRecord.confidence * 100))
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                else {
                    Text("No detection yet")
                            .foregroundColor(.gray)
                            .padding()
                }
                // Debug info for audio data
                VStack {
                    Text("Frequency: \(String(format: "%.2f", audioRecorder.frequency)) Hz")
                        .foregroundColor(.white)
                    Text("Amplitude: \(String(format: "%.2f", audioRecorder.amplitude))")
                        .foregroundColor(.white)
                }
                .padding()

                // New dedicated section for sensor outputs
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sensor Outputs")
                        .font(.headline)
                        .foregroundColor(.white)


                    // GPS Data
                    if let location = locationManager.currentLocation {
                        Text("GPS: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                            .foregroundColor(.white)
                    } else {
                        Text("GPS: Waiting for data...")
                            .foregroundColor(.gray)
                    }

                    // Heart Rate Output
                    if let heartRate = heartRateManager.heartRate {
                        Text("Heart Rate: \(String(format: "%.0f", heartRate)) BPM")
                            .foregroundColor(.white)
                    }

                    // Pressure Data using the built-in altimeter
                    if let pressure = pressureManager.pressure {
                        Text("Pressure: \(String(format: "%.2f", pressure)) hPa")
                            .foregroundColor(.white)
                    } else {
                        Text("Pressure: Waiting for data...")
                            .foregroundColor(.gray)
                    }

                    // Orientation Data (Pitch, Roll, Yaw)
                    if let attitude = orientationManager.attitude {
                        Text("Orientation: Pitch \(String(format: "%.2f", attitude.pitch)), Roll \(String(format: "%.2f", attitude.roll)), Yaw \(String(format: "%.2f", attitude.yaw))")
                            .foregroundColor(.white)
                    } else {
                        Text("Orientation: Waiting for data...")
                            .foregroundColor(.gray)
                    }

                    // Gyroscope Data
                    if let rotation = gyroscopeManager.rotationRate {
                        Text("Gyroscope: X \(String(format: "%.2f", rotation.x)), Y \(String(format: "%.2f", rotation.y)), Z \(String(format: "%.2f", rotation.z))")
                            .foregroundColor(.white)
                    } else {
                        Text("Gyroscope: Waiting for data...")
                            .foregroundColor(.gray)
                    }

                    // Altitude Data
                    if let altitude = locationManager.currentLocation?.altitude {
                        Text("Altitude: \(String(format: "%.2f", altitude)) m")
                            .foregroundColor(.white)
                    } else {
                        Text("Altitude: Waiting for data...")
                            .foregroundColor(.gray)
                    }

                    // Relative Altitude
                    if let relativeAltitude = altitudeManager.relativeAltitude {
                        Text("Relative Altitude: \(String(format: "%.2f", relativeAltitude)) m").foregroundColor(.white)
                    } else {
                        Text("Relative Altitude: Waiting for data...")
                            .foregroundColor(.gray)
                    }

                    // Floors Climbed
                    if let floorsClimbed = floorCounter.floorDelta {
                        Text("Floors Climbed: \(String(format: "%.0f", floorsClimbed)) floors").foregroundColor(.white)

                    } else {
                        Text("Floors Climbed: Waiting for data...")
                            .foregroundColor(.gray)
                    }


                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer()

                // Microphone toggle button for audio recording
                Button(action: {
                    audioRecorder.toggleRecording()
                }) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(audioRecorder.isRecording ? Color.red : Color.blue)
                        .cornerRadius(25)
                        .foregroundColor(.white)
                }
                .padding()
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Detection", displayMode: .inline)
            .navigationBarItems(trailing: menuButton)
        }
        .sheet(item: $exportItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .onAppear {
            heartRateManager.requestAuthorization()
            locationManager.startUpdating()

            NotificationCenter.default.addObserver(forName: Notification.Name("DetectionOccurred"), object: nil, queue: .main) { notification in
                let record = DetectionRecord(
                    timestamp: notification.userInfo?["timestamp"] as? Date ?? Date(),
                    gpsLatitude: locationManager.currentLocation?.coordinate.latitude ?? 0.0,
                    gpsLongitude: locationManager.currentLocation?.coordinate.longitude ?? 0.0,
                    pressure: pressureManager.pressure ?? 0.0,
                    orientationPitch: orientationManager.attitude?.pitch ?? 0.0,
                    orientationRoll: orientationManager.attitude?.roll ?? 0.0,
                    orientationYaw: orientationManager.attitude?.yaw ?? 0.0,
                    gyroX: gyroscopeManager.rotationRate?.x ?? 0.0,
                    gyroY: gyroscopeManager.rotationRate?.y ?? 0.0,
                    gyroZ: gyroscopeManager.rotationRate?.z ?? 0.0,
                    heartrate: heartRateManager.heartRate ?? 0.0,
                    altitude: locationManager.currentLocation?.altitude ?? 0.0,
                    relativeAltitude: altitudeManager.relativeAltitude ?? 0.0,
                    floorsClimbed: floorCounter.floorDelta ?? 0.0,
                    audioFilePath: audioRecorder.audioFilePath,
                    result: notification.userInfo?["result"] as? String ?? "",
                    confidence: notification.userInfo?["confidence"] as? Double ?? 0.0,
                    uploadStatus: "Pending"
                )
                detectionStore.records.append(record)
                print("Detection record saved: \(record)")

                // Save the record to Realm immediately
                saveToRealm(record: record)
            }

        }

    }

    var menuButton: some View {
        Menu {
            Button(action: { exportData(type: "WAV") }) {
                Label("Export Audio (WAV)", systemImage: "waveform")
            }
            Button(action: { exportCSV() }) {
                Label("Export Detections (CSV)", systemImage: "square.and.arrow.down")
            }
            Button(action: {
                uploadDetectionRecords()
            }) {
                Text("Upload Detection Data")
            }
            Divider()
            Button(role: .destructive, action: deleteData) {
                Label("Delete Data", systemImage: "trash")
            }
            Button(action: showAbout) {
                Label("About", systemImage: "info.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
        }
    }

    func exportData(type: String) {
        if type == "WAV" {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Documents directory not found")
                return
            }
            do {
                // Get all files in Documents that are gunshot clips
                let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                let gunshotFiles = files.filter {
                    $0.lastPathComponent.hasPrefix("gunshot_") && $0.pathExtension.lowercased() == "caf"
                }
                
                if gunshotFiles.isEmpty {
                    print("No gunshot audio clip files found.")
                    return
                }
                
                // Create the zip file URL
                let zipFileURL = documentsDirectory.appendingPathComponent("audioClips.zip")
                
                // Remove existing zip file if present
                if fileManager.fileExists(atPath: zipFileURL.path) {
                    try fileManager.removeItem(at: zipFileURL)
                }
                
                // Use the new throwing initializer
                let archive = try Archive(url: zipFileURL, accessMode: .create)
                
                // Add each gunshot file to the archive
                for fileURL in gunshotFiles {
                    try archive.addEntry(with: fileURL.lastPathComponent, relativeTo: documentsDirectory)
                }
                
                DispatchQueue.main.async {
                    self.exportItem = ExportItem(url: zipFileURL)
                    print("Exporting audio ZIP file from: \(zipFileURL.path)")
                }
            } catch {
                print("Error exporting audio ZIP: \(error)")
            }
        } else if type == "CSV" {
            print("Exporting \(type) file...")
            // Add your CSV export logic here.
        }
    }

    func deleteData() {
        removeUploadedRecords() // Call function to remove uploaded records from the database
        print("Deleting data...") // Print a message indicating data deletion
    }
    
    func showAbout() {
        print("Showing About screen...") // Print a message indicating the About screen is being shown
    }
    
    func exportCSV() {
        // Updated CSV header with units for each column.
        var csvText = "Timestamp (UTC), GPS_Latitude (°), GPS_Longitude (°), Pressure (hPa), Orientation_Pitch (°), Orientation_Roll (°), Orientation_Yaw (°), Gyro_X (°/s), Gyro_Y (°/s), Gyro_Z (°/s), HeartRate (BPM), Altitude(m), Relative Altitude (m), Floors Climbed (floors) \n"
        
        // Build CSV rows from each detection record.
        for record in detectionStore.records {
            let heartRateValue = record.heartrate // Get the heart rate value from the record
            // The timestamp here is printed using its default description.
            // You might want to format the date if needed.
            let newLine = "\(record.timestamp),\(record.gpsLatitude),\(record.gpsLongitude),\(record.pressure),\(record.orientationPitch),\(record.orientationRoll),\(record.orientationYaw),\(record.gyroX),\(record.gyroY),\(record.gyroZ),\(record.heartrate), \(record.altitude), \(record.relativeAltitude), \(record.floorsClimbed) \n" // Create a new CSV line with record data

            csvText.append(newLine) // Append the new line to the CSV text
        }
        
        // Write CSV to a file in the Documents directory.
        let fileManager = FileManager.default // Get the default file manager
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first { // Get the URL for the Documents directory
            let fileURL = documentsDirectory.appendingPathComponent("sensorData.csv") // Create the file URL for the CSV file
            do {
                try csvText.write(to: fileURL, atomically: true, encoding: .utf8) // Write the CSV text to the file
                DispatchQueue.main.async { // Perform UI updates on the main thread
                    self.exportItem = ExportItem(url: fileURL) // Set the export item to the created file URL
                }
                print("CSV file successfully created at: \(fileURL.path)") // Print a success message with the file path
            } catch {
                print("Error writing CSV file: \(error)") // Print an error message if writing fails
            }
        }
    }
    
    //Function to save to Realm Database
    func saveToRealm(record: DetectionScreen.DetectionRecord) {
        let realm = try! Realm() // Create a Realm instance
        let realmRecord = DetectionRecordRealm() // Create a new Realm object for the detection record
        realmRecord.id = record.id.uuidString // Set the ID of the Realm record
        realmRecord.timestamp_UTCTime = record.timestamp // Set the timestamp
        realmRecord.gpsLatitude_DEG = record.gpsLatitude // Set the GPS latitude
        realmRecord.gpsLongitude_DEG = record.gpsLongitude // Set the GPS longitude
        realmRecord.pressure_hPA = record.pressure // Set the pressure
        realmRecord.orientationPitch_RAD = record.orientationPitch // Set the orientation pitch
        realmRecord.orientationRoll_RAD = record.orientationRoll // Set the orientation roll
        realmRecord.orientationYaw_RAD = record.orientationYaw // Set the orientation yaw
        realmRecord.gyroX_RAD_SEC = record.gyroX // Set the gyroscope X value
        realmRecord.gyroY_RAD_SEC = record.gyroY // Set the gyroscope Y value
        realmRecord.gyroZ_RAD_SEC = record.gyroZ // Set the gyroscope Z value
        realmRecord.heartrate_BPM = record.heartrate // Set the heart rate
        realmRecord.altitude_M = record.altitude // Set the altitude
        realmRecord.relativeAltitude_M = record.relativeAltitude // Set the relative altitude
        realmRecord.floorsClimbed_Floors = record.floorsClimbed // Set the floors climbed
        realmRecord.audioFilePath = record.audioFilePath // Set the audio file path
        realmRecord.result = record.result // Set the detection result
        realmRecord.confidence_PERCENT = record.confidence * 100 // Set the confidence percentage
        realmRecord.uploadStatus = record.uploadStatus // Set the upload status
        
        
        // Save to Realm
        try! realm.write {
            realm.add(realmRecord) // Add the new Realm record to the database
        }
        print("Realm write complete") // Print a message indicating successful write to Realm
        
        if sendToServer(records: [realmRecord]) { // Attempt to send the record to the server
            try! realm.write {
                realmRecord.uploadStatus = "Complete" // Update the upload status to "Complete" if successful
            }
            print("Writing Realm record staus as Complete") // Print a message indicating status update
        } else {
            try! realm.write {
                realmRecord.uploadStatus = "Failed" // Update the upload status to "Failed" if sending fails
            }
            print("Writing Realm record status as Failed") // Print a message indicating status update
            //startRetryLoop()
            //print("Starting Retry Timer")
        }
    }

    
    func uploadDetectionRecords() {
        let realm = try! Realm() // Create a Realm instance
        let detectionRecords = realm.objects(DetectionRecordRealm.self) // Fetch all detection records from Realm
        
        // Iterate over the records and upload them to the server
        for record in detectionRecords {
            // Create a record in the format expected by your server
            let detectionRecord = DetectionRecord(
                timestamp: record.timestamp_UTCTime, // Get timestamp from Realm record
                gpsLatitude: record.gpsLatitude_DEG, // Get GPS latitude from Realm record
                gpsLongitude: record.gpsLongitude_DEG, // Get GPS longitude from Realm record
                pressure: record.pressure_hPA, // Get pressure from Realm record
                orientationPitch: record.orientationPitch_RAD, // Get orientation pitch from Realm record
                orientationRoll: record.orientationRoll_RAD, // Get orientation roll from Realm record
                orientationYaw: record.orientationYaw_RAD, // Get orientation yaw from Realm record
                gyroX: record.gyroX_RAD_SEC, // Get gyroscope X value from Realm record
                gyroY: record.gyroY_RAD_SEC, // Get gyroscope Y value from Realm record
                gyroZ: record.gyroZ_RAD_SEC, // Get gyroscope Z value from Realm record
                heartrate: record.heartrate_BPM, // Get heart rate from Realm record
                altitude: record.altitude_M, // Get altitude from Realm record
                relativeAltitude: record.relativeAltitude_M, // Get relative altitude from Realm record
                floorsClimbed: record.floorsClimbed_Floors, // Get floors climbed from Realm record
                audioFilePath: record.audioFilePath, // Get audio file path from Realm record
                result: record.result, // Get detection result from Realm record
                confidence: record.confidence_PERCENT, // Get confidence percentage from Realm record
                uploadStatus: record.uploadStatus // Get upload status from Realm record
            )
        }
    }

    
    func retryFailedUploads() {
        let realm = try! Realm() // Create a Realm instance
        let failedRecords = realm.objects(DetectionRecordRealm.self).filter("uploadStatus == Failed") // Fetch records with failed upload status
        print("Found \(failedRecords.count) failed records.") // Print the number of failed records found
        print("Retrying upload for failed records") // Print a message indicating retry attempt
        
        if sendToServer(records: Array(failedRecords)) { // Attempt to send all failed records to the server
            for realmRecord in failedRecords { // Iterate over the failed records
                try! realm.write {
                    realmRecord.uploadStatus = "Complete" // Update the upload status to "Complete" for each successfully sent record
                }
            }
            print("Writing failed record status as Complete") // Print a message indicating status update
            stopRetryLoop() // Stop the retry loop after successful upload
            print("Stopping Retry timer") // Print a message indicating the timer is stopped
        }
    }
    func sendToServer(records: [DetectionRecordRealm]) -> Bool {
        let client = GRPCClient() // Create a GRPC client instance
        
        var detections = Signalq_Detections() // Create a Signalq_Detections message
        var detectionRequest = Signalq_DetectionMessage() // Create a Signalq_DetectionMessage

        for record in records { // Iterate over the detection records to be sent
            
            var locationMessage = Signalq_Location() // Create a Signalq_Location message
            locationMessage.latitude = record.gpsLatitude_DEG // Set the latitude
            locationMessage.longitude = record.gpsLongitude_DEG // Set the longitude
            
            var orientationMessage = Signalq_Orientation() // Create a Signalq_Orientation message
            orientationMessage.pitch = record.orientationPitch_RAD // Set the pitch
            orientationMessage.roll = record.orientationRoll_RAD // Set the roll
            orientationMessage.yaw = record.orientationYaw_RAD // Set the yaw
            
            var gyroscopeMessage = Signalq_Gyroscope() // Create a Signalq_Gyroscope message
            gyroscopeMessage.x = record.gyroX_RAD_SEC // Set the X value
            gyroscopeMessage.y = record.gyroY_RAD_SEC // Set the Y value
            gyroscopeMessage.z = record.gyroZ_RAD_SEC // Set the Z value
            
            var sensorData = Signalq_SensorData() // Create a Signalq_SensorData message
            sensorData.location = locationMessage // Set the location data
            sensorData.pressure = record.pressure_hPA // Set the pressure
            sensorData.orientation = orientationMessage // Set the orientation data
            sensorData.gyroscope = gyroscopeMessage // Set the gyroscope data
            sensorData.heartrate = record.heartrate_BPM // Set the heart rate
            sensorData.altitude = record.altitude_M // Set the altitude
            sensorData.relativeAltitude = record.relativeAltitude_M // Set the relative altitude
            sensorData.floorsClimbed = record.floorsClimbed_Floors // Set the floors climbed
            
            //need to add relative altitude and floors climbed here
            
            detectionRequest = Signalq_DetectionMessage() // Create a new Signalq_DetectionMessage for each record
            detectionRequest.id = record.id // Set the ID
            detectionRequest.timeUtcMilliseconds = Int64(record.timestamp_UTCTime.timeIntervalSince1970 * 1000) // Set the timestamp in milliseconds
            detectionRequest.sensors = sensorData // Set the sensor data
            
        }
        
        detections.detections.append(detectionRequest) // Append the detection request to the detections message
        
        Task {
            do {
                try await client.runClient(detections: detections) // Asynchronously run the GRPC client to send data
                return true // Return true if the client runs successfully
            } catch {
                print("Error running client: \(error)") // Print an error message if the client fails
                return false // Return false if the client fails
            }
        }
        return false // Return false immediately, the actual result is handled in the Task
    }
    
    func removeUploadedRecords() {
        let realm = try! Realm() // Create a Realm instance
        let detectionRecords = realm.objects(DetectionRecordRealm.self) // Fetch all detection records from Realm
        
        try! realm.write {
            realm.delete(detectionRecords) // Delete all fetched detection records from Realm
        }
        print("All uploaded records deleted from Realm.") // Print a message indicating successful deletion
    }
    
}


struct ContentView: View {
    @State private var currentScreen: Screen = .splashScreen // State to manage the current screen being displayed
    
    enum Screen {
        case splashScreen // Represents the splash screen
        case landingPage // Represents the landing page
        case detectionScreen // Represents the detection screen
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Show SplashScreen initially
                if currentScreen == .splashScreen {
                    SplashScreen() // Display the splash screen
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // After 2 seconds
                                currentScreen = .landingPage // Transition to the landing page
                            }
                        }
                    
                } else if currentScreen == .landingPage {
                    LandingPage() // Display the landing page
                }
            }
            .edgesIgnoringSafeArea(.all) // Ignore safe area insets for the view
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView() // Provide a preview of the ContentView
    }
}
