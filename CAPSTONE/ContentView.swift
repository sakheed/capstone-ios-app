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

    

    @State private var exportItem: ExportItem? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // Display current GPS data
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
                
                // Existing GPS status indicator (you may update this accordingly)
                HStack {
                    Text("GPS: Active")
                        .font(.headline)
                        .foregroundColor(.green)
                    Spacer()
                    // Optionally, update the time display here if needed
                    Text(Date(), style: .time)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                
                // Your detection confidence views, audio recording display, etc.
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
                
                Spacer()
                
                // Microphone button for toggling recording
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
        // Present the share sheet when exportItem is non-nil.
        .sheet(item: $exportItem) { item in
            ActivityView(activityItems: [item.url])
        }
        // Optionally start location updates when the view appears.
        .onAppear {
            locationManager.startUpdating()
        }
    }
    
    // MARK: - Dropdown Menu
    var menuButton: some View {
        Menu {
            Button(action: { exportData(type: "WAV") }) {
                Label("Export Audio (WAV)", systemImage: "waveform")
            }
            Button(action: { exportData(type: "CSV") }) {
                Label("Export Detections (CSV)", systemImage: "square.and.arrow.down")
            }
            Divider() //
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
