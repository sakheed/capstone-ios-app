import SwiftUI
import AVFoundation

// QRScannerView integrates AVCaptureSession into SwiftUI via UIViewControllerRepresentable
struct QRScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var scannedURL: String? // Store scanned URL

    // Coordinator handles metadata output delegate methods for QR scanning
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRScannerView
        
        init(parent: QRScannerView) {
            self.parent = parent
        }
        
        // Called when metadata objects are detected by the capture session
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let scannedData = metadataObject.stringValue {
                
                print("Scanned QR Code: \(scannedData)")
                
                DispatchQueue.main.async {
                    self.parent.scannedURL = scannedData // Save scanned URL
                    self.parent.isPresented = false // Close scanner
                    
                    // Open the URL in Safari
                    if let url = URL(string: scannedData), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        print("Invalid QR Code URL")
                    }
                }
            }
        }
    }
    
    // Create Coordinator instance for UIViewControllerRepresentable
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    // Set up camera capture session and preview, return configured UIViewController
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        // Initialize capture session
        let captureSession = AVCaptureSession()

        // Ensure back camera is available
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No Camera Found")
            return viewController
        }
        
        do {
            // Add camera input to session
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("Error Setting Up Camera Input: \(error)")
            return viewController
        }
        
        // Configure metadata output for QR detection
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        
        // Configure preview layer for live camera feed
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)

        // Start capture session asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        return viewController
    }
    
    // Update method required by protocol; no dynamic updates needed
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
