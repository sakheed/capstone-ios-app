# Signal Q iOS App 
**Team:** Sakhee Desai, Aman Singh, Benita Abraham, Charmaine Pasicolan, Alexander Hoy

---

## Project Brief: 
**SignalQ** is a SwiftUI-based iOS app designed to record low latency audio and detect gunshots using a CoreML machine learning classifier model. Upon detection, it records data from multiple sensors including GPS, heart rate, gyroscope, and pressure. All data is saved locally with Realm and then uploaded to a backend using gRPC.

---

## Requirements and Cloning the Repo 
### 1. Clone the Repo with Submodules
If you’re cloning the repo for the first time, use:
```
git clone --recurse-submodules https://gitlab.eecis.udel.edu/cisc-capstone-teams/2024-2025/team-22/ios-app.git
```
To update the submodule to the latest version later:
```
git submodule update --remote
```

### 2. Install Python Dependencies
```
pip install grpcio grpcio-tools
```
### 3. Generate proto files
The generated files should exist in the repository to start off, but if any changes are made to the `detections.proto` file, run the following make commands in the `./ios-app/CAPSTONE` path
```
make proto
```
OR
```
make python-proto
make swift-proto
```
**Note**: If there is an error on line 6 of ./proto-repo/generated/detection_pb2_grpc.py, change it to 
```
from . import detection_pb2 as detection__pb2
```
### 4. Start the gRPC server
Starts the backend server on port 50051
```
make start-server
```
To see whether the server is listening, run:
```
lsof -i :50051
```

### 5. Build the project on XCode

[Any other steps here]

### 6. Kill the server
To ensure the server has been terminated, run:
```
make kill-server
```


---

## 📂 Key Components and File Responsibilities

### `CAPSTONEApp.swift`
- App entry point.
- Generates Realm database instance
- Injects `DetectionDataStore` into the environment for app-wide use.

---

### `ContentView.swift`
- **Navigation & Screens**:
  - Displays splash screen, landing page, and detection interface.
- **LandingPage**:
  - Contains brand visuals, website link, QR registration, and activation.
- **DetectionScreen**:
  - Displays real-time sensor data.
  - Records are created upon notification from audio classifier.
  - Allows export of audio (WAV ZIP) and sensor logs (CSV).
  - Upload functionality to remote server via gRPC.

#### 🔑 Key Functions:
- `saveToRealm(record:)`: Saves event data to Realm and triggers `sendToServer`
- `sendToServer(records:)`: Converts Realm record data to proto and uploads.
- `exportCSV()`, `exportData(type:)`: Exports collected data.
- `retryFailedUploads()`: Retries uploads for failed records.

---

### `AudioRecorder.swift`
- Core engine to manage audio analysis and recording.
- Uses AudioKit and Apple SoundAnalysis framework.
- Maintains a rolling buffer to capture pre/post-trigger audio.
- See DOCUMENTATION folder for details on how to create and train a CoreML model within XCode. 

#### 🔑 Key Functions:
- `startRecording()` / `stopRecording()`: Manage AudioKit engine.
- `storeAudioBuffer(_:)`: Updates rolling buffer, detects trigger, stores data.
- `analyzeAudio(_:)`: Runs sound classification.
- `saveGunshotClip(buffers:)`: Writes `.caf` audio file and triggers `NotificationCenter`.

#### 🔄 Process Flow:
1. Audio stream starts.
2. Buffer sent to CoreML classifier.
3. If gunshot confidence > 0.8, record is triggered.
4. Pre/post audio segments combined and saved.
5. A notification is posted to initiate full sensor data capture.

---

### `QRScannerView.swift`
- QR code scanner built with `AVFoundation`.
- Supports automatic URL open and scanning feedback.

#### 🔑 Key Functions:
- `makeUIViewController(context:)`: Camera setup.
- `metadataOutput(_:didOutput:)`: QR code detection and handling.

---

## 🧪 Sensor Managers
- `LocationManager`
- `HeartRateManager.swift`
- `OrientationManager.swift`
- `PressureManager.swift`
- `GyroscopeManager.swift`
- `AltitudeManager.swift`
- `FloorCounter.swift`

Each of these uses `@Published` properties to expose live data to the UI.

---

## ☁️ Uploading and Server Integration
This project implements a Python-based gRPC client and server for sending structured detection messages, including location and sensor data (e.g., gunshot detections), over the network using Protocol Buffers.

### `proto-repo/proto/detection.proto`
- Defines a Detection service that sends a `DetectionMessage` and and returns an `Acknowledgement` message
- `Acknowledgement`: either `true` for Ack or `false` for Nack and a reason for failure, if applicable
- `DetectionMessage`: contains all time, location, sensor and classification data for each detection the detection 
- The service can one or more detections at once

### `proto-repo/server/server.py`
- Server listens for incoming Detection messages and responds with Acknowledgement true
- Starts the server on port 50051

### `GRPClient.swift`
- Client side code with GRPCClient
- `runClient(detections: Signalq_Detections)`: Takes a detection record and sets up target host (127.0.0.1) and port (50051). **Note**: target host should be the IP address of the phone used for testing.
- `sendDetection(using detectionService: Signalq_DetectionService.ClientProtocol, detections: Signalq_Detections)`: calls the gRPC method in the generated swift files using ClientProtocol; prints the response from the server

### `detection.grpc.swift` and `detection.pb.swift`
**Do not edit these files!** These files are generated from the `make proto` command containing client stubs for the gRPC service.


---

## 📤 Export Features
- **WAV ZIP Export**: Packs all `gunshot_*.caf` audio clips into a `audioClips.zip` archive.
- **CSV Export**: Exports sensor metadata in human-readable format.
- Accessible through the UI menu on the Detection screen.

---





