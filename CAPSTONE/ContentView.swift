//
//  ContentView.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 2/11/25.
//

import SwiftUI
import UIKit
import ZIPFoundation
import RealmSwift

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}


struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            Image(systemName: "waveform")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.blue)
        }
    }
}

struct LandingPage: View {
    @State private var isShowingScanner = false
    @State private var navigateToDetectionScreen = false
    @State private var scannedURL: String? // Store the scanned URL
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "waveform")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.blue)
                
                Text("Welcome to SignalQ!")
                    .font(.title2)
                    .foregroundColor(.white)
                
                //Company url
                Link("Visit SignalQ Website", destination: URL(string: "https://www.signalq.com")!)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                //Description of app
                Text("SignalQ is a software-only signal intelligence platform that provides a low-cost, simple to incorporate, military-grade event detection capability that can leverage freely-associated mobile phones as sensors.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                
                
                // QR Code Scanner Button
                Button(action: {
                    isShowingScanner = true
                }) {
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
                // Activation Button
                Button(action: {
                    navigateToDetectionScreen = true
                }) {
                    Text("Activate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0x4E / 255, green: 0xAB / 255, blue: 0xE2 / 255))
                        .cornerRadius(50)
                        .foregroundColor(Color(red: 0x25 / 255, green: 0x29 / 255, blue: 0x32 / 255))
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
        
        .onChange(of: scannedURL) { newURL, _ in
            if let urlString = newURL, let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                print("❌ Invalid QR Code URL")
            }
        }
    }
}

//Realm Database version of DetectionRecord
class DetectionRecordRealm: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var timestamp: Date
    @Persisted var gpsLatitude: Double
    @Persisted var gpsLongitude: Double
    @Persisted var pressure: Double
    @Persisted var orientationPitch: Double
    @Persisted var orientationRoll: Double
    @Persisted var orientationYaw: Double
    @Persisted var gyroX: Double
    @Persisted var gyroY: Double
    @Persisted var gyroZ: Double
    @Persisted var audioFilePath: String
}

class DetectionDataStore: ObservableObject {
    @Published var records: [DetectionScreen.DetectionRecord] = []
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
        let audioFilePath: String
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
    
    @State private var exportItem: ExportItem? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let location = locationManager.currentLocation {
                    VStack(spacing: 4) {
                        Text("Latitude: \(location.coordinate.latitude)")
                            .foregroundColor(.white)
                        Text("Longitude: \(location.coordinate.longitude)")
                            .foregroundColor(.white)
                    }
                    .padding()
                } else {
                    Text("Waiting for location...")
                        .foregroundColor(.gray)
                        .padding()
                }
                
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
                
                // Detection confidence views
                VStack {
                    HStack {
                        Text("Hands")
                            .foregroundColor(.white)
                        Spacer()
                        ProgressView(value: 0.85)
                    }
                    HStack {
                        Text("Finger Snapping")
                            .foregroundColor(.white)
                        Spacer()
                        ProgressView(value: 0.41)
                    }
                    HStack {
                        Text("Clapping")
                            .foregroundColor(.white)
                        Spacer()
                        ProgressView(value: 0.15)
                    }
                }
                .padding()
                
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
                // Capture the sensor data snapshot at the time of detection.
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
                    audioFilePath: audioRecorder.audioFilePath
                )
                detectionStore.records.append(record)
                print("Detection record saved: \(record)")
                
                // Save the record to Realm immediately
                saveToRealm(record: record)
                print("Detection record saved to Realm: \(record)")
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
                
                // ✅ Use the new throwing initializer
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
        print("Deleting data...")
    }
    
    func showAbout() {
        print("Showing About screen...")
    }
    
    func exportCSV() {
        // CSV header remains the same.
        var csvText = "Timestamp,GPS_Latitude,GPS_Longitude,Pressure,Orientation_Pitch,Orientation_Roll,Orientation_Yaw,Gyro_X,Gyro_Y,Gyro_Z\n"
        
        // Build CSV rows from each detection record.
        for record in detectionStore.records {
            let newLine = "\(record.timestamp),\(record.gpsLatitude),\(record.gpsLongitude),\(record.pressure),\(record.orientationPitch),\(record.orientationRoll),\(record.orientationYaw),\(record.gyroX),\(record.gyroY),\(record.gyroZ)\n"
            csvText.append(newLine)
        }
        
        // Write CSV to a file in the Documents directory.
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("sensorData.csv")
            do {
                try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    self.exportItem = ExportItem(url: fileURL)
                }
                print("CSV file successfully created at: \(fileURL.path)")
            } catch {
                print("Error writing CSV file: \(error)")
            }
        }
    }
    
    //Function to save to Realm Database
    func saveToRealm(record: DetectionRecord) {
        let realm = try! Realm()
        let realmRecord = DetectionRecordRealm()
        
        realmRecord.id = record.id.uuidString
        realmRecord.timestamp = record.timestamp
        realmRecord.gpsLatitude = record.gpsLatitude
        realmRecord.gpsLongitude = record.gpsLongitude
        realmRecord.pressure = record.pressure
        realmRecord.orientationPitch = record.orientationPitch
        realmRecord.orientationRoll = record.orientationRoll
        realmRecord.orientationYaw = record.orientationYaw
        realmRecord.gyroX = record.gyroX
        realmRecord.gyroY = record.gyroY
        realmRecord.gyroZ = record.gyroZ
        realmRecord.audioFilePath = record.audioFilePath
        
        // Save to Realm
        try! realm.write {
            realm.add(realmRecord)
        }
        print("Record saved to Realm: \(realmRecord)")
    }
    
    func uploadDetectionRecords() {
        let realm = try! Realm()
        let detectionRecords = realm.objects(DetectionRecordRealm.self)
        
        // Iterate over the records and upload them to the server
        for record in detectionRecords {
            // Create a record in the format expected by your server
            let detectionRecord = DetectionRecord(
                timestamp: record.timestamp,
                gpsLatitude: record.gpsLatitude,
                gpsLongitude: record.gpsLongitude,
                pressure: record.pressure,
                orientationPitch: record.orientationPitch,
                orientationRoll: record.orientationRoll,
                orientationYaw: record.orientationYaw,
                gyroX: record.gyroX,
                gyroY: record.gyroY,
                gyroZ: record.gyroZ,
                audioFilePath: record.audioFilePath
            )
            
            sendServer(record: detectionRecord)
        }
    }

    func sendServer(record: DetectionRecord) {
        let client = GRPCClient()
        
        var locationMessage = Signalq_Location()
        locationMessage.latitude = record.gpsLatitude
        locationMessage.longitude = record.gpsLongitude
        
        var orientationMessage = Signalq_Orientation()
        orientationMessage.pitch = record.orientationPitch
        orientationMessage.roll = record.orientationRoll
        orientationMessage.yaw = record.orientationYaw
        
        var gyroscopeMessage = Signalq_Gyroscope()
        gyroscopeMessage.x = record.gyroX
        gyroscopeMessage.y = record.gyroY
        gyroscopeMessage.z = record.gyroZ
        
        var sensorData = Signalq_SensorData()
        sensorData.location = locationMessage
        sensorData.pressure = record.pressure
        sensorData.orientation = orientationMessage
        sensorData.gyroscope = gyroscopeMessage
        
        var detectionRequest = Signalq_Detection()
        detectionRequest.id = record.id.uuidString
        detectionRequest.timeUtcMilliseconds = Int64(record.timestamp.timeIntervalSince1970 * 1000)
        detectionRequest.sensors = sensorData
        
        Task {
            do {
                try await client.runClient(detectionRequest: detectionRequest)
            } catch {
                print("Error running client: \(error)")
            }
        }
    }
    
    func removeUploadedRecords() {
        let realm = try! Realm()
        let detectionRecords = realm.objects(DetectionRecordRealm.self)
        
        try! realm.write {
            realm.delete(detectionRecords)
        }
        print("All uploaded records deleted from Realm.")
    }
    
}


struct ContentView: View {
    @State private var currentScreen: Screen = .splashScreen
    
    enum Screen {
        case splashScreen
        case landingPage
        case detectionScreen
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Show SplashScreen initially
                if currentScreen == .splashScreen {
                    SplashScreen()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                currentScreen = .landingPage
                            }
                        }
                    
                } else if currentScreen == .landingPage {
                    LandingPage()
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
