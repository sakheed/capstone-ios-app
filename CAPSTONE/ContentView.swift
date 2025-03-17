//
//  ContentView.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 2/11/25.
//

import SwiftUI
import UIKit


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
                        .background(Color.gray)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
                .frame(width: 200)
                .sheet(isPresented: $isShowingScanner) {
                    QRScannerView(isPresented: $isShowingScanner, scannedURL: $scannedURL)
                }

                // Activation Button
                Button(action: {
                    
                }) {
                    Text("Activate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
                .frame(width: 200)
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



struct DetectionScreen: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var locationManager = LocationManager()
    
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
            locationManager.startUpdating()
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
    
    // MARK: - Action Handlers
    func exportData(type: String) {
        if type == "WAV" {
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("combinedAudio.caf")
                print("Looking for file at: \(fileURL.path)")
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: documentsDirectory.path)
                    print("Documents directory contents: \(contents)")
                } catch {
                    print("Error listing Documents directory: \(error)")
                }
                
                if fileManager.fileExists(atPath: fileURL.path) {
                    DispatchQueue.main.async {
                        self.exportItem = ExportItem(url: fileURL)
                        print("Exporting audio file from: \(fileURL.path)")
                    }
                } else {
                    print("❌ Combined audio file not found at expected path.")
                }
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
        // Build CSV header
        var csvText = "Timestamp,GPS_Latitude,GPS_Longitude,Pressure,Orientation_Pitch,Orientation_Roll,Orientation_Yaw,Gyro_X,Gyro_Y,Gyro_Z\n"
        
        // Capture current sensor data
        let timestamp = Date()
        let gpsLatitude = locationManager.currentLocation?.coordinate.latitude ?? 0.0
        let gpsLongitude = locationManager.currentLocation?.coordinate.longitude ?? 0.0
        let pressureValue = pressureManager.pressure ?? 0.0
        let orientationPitch = orientationManager.attitude?.pitch ?? 0.0
        let orientationRoll = orientationManager.attitude?.roll ?? 0.0
        let orientationYaw = orientationManager.attitude?.yaw ?? 0.0
        let gyroX = gyroscopeManager.rotationRate?.x ?? 0.0
        let gyroY = gyroscopeManager.rotationRate?.y ?? 0.0
        let gyroZ = gyroscopeManager.rotationRate?.z ?? 0.0
        
        // Create a CSV row
        let newLine = "\(timestamp),\(gpsLatitude),\(gpsLongitude),\(pressureValue),\(orientationPitch),\(orientationRoll),\(orientationYaw),\(gyroX),\(gyroY),\(gyroZ)\n"
        csvText.append(newLine)
        
        // Write CSV to a file in the Documents directory
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("sensorData.csv")
            do {
                try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                // Set the export item to show the share sheet (for testing, the user can "Save to Files")
                DispatchQueue.main.async {
                    self.exportItem = ExportItem(url: fileURL)
                }
                print("CSV file successfully created at: \(fileURL.path)")
            } catch {
                print("Error writing CSV file: \(error)")
            }
        }
    }


}


struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: SplashScreen()) {
                    Text("Go to Splash Screen")
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
                
                NavigationLink(destination: LandingPage()) {
                    Text("Go to Landing Page")
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
                
                NavigationLink(destination: DetectionScreen()) {
                    Text("Go to Detection Screen")
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
            }
            .padding()
        }
    }
}


#Preview {
    ContentView()
}


#Preview {
    SplashScreen()
}

#Preview {
    LandingPage()
}

#Preview {
    DetectionScreen()
}
