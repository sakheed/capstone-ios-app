//
//  ContentView.swift
//  CAPSTONE
//
//  Created by Sakhee Desai on 2/11/25.
//

import SwiftUI

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
                    // Activation logic
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
        .onChange(of: scannedURL) { newURL in
            if let urlString = newURL, let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                print("❌ Invalid QR Code URL")
            }
        }
    }
}


struct DetectionScreen: View {
    @StateObject private var audioRecorder = AudioRecorder() // Audio Recorder instance
    
    var body: some View {
        NavigationView {
            VStack {
                // Top Status Section
                HStack {
                    Text("GPS: Active")
                        .font(.headline)
                        .foregroundColor(.green)
                    Spacer()
                    Text("11:02:41")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                
                // Detection Confidence List
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
                
                // Debug info to display live amplitude and frequency
                VStack {
                    Text("Frequency: \(String(format: "%.2f", audioRecorder.frequency)) Hz")
                        .foregroundColor(.white)
                    Text("Amplitude: \(String(format: "%.2f", audioRecorder.amplitude))")
                        .foregroundColor(.white)
                }
                .padding()
                
                Spacer()
                
                // Microphone Button for Toggling Recording
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
            Divider() // Adds a visual separator
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
        print("Exporting \(type) file...")
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
