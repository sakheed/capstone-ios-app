import Foundation
import AVFoundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import SoundAnalysis

import CoreML

// AudioRecorder captures audio, detects gunshots, and manages buffer snapshots
class AudioRecorder: ObservableObject {
    // Core audio engine for capturing sound
    var engine = AudioEngine()
    // Microphone input node
    var mic: AudioEngine.InputNode
    
    // Mixer for routing audio through pitch tracker
    var mixer: Mixer         // For PitchTap (frequency/amplitude)
    // Mixer for installing tap to capture buffers
    var detectionMixer: Mixer // For installing a tap
    
    // PitchTap for measuring audio frequency and amplitude
    var tracker: PitchTap!
    
    // Rolling buffer storing recent audio before an event
    var rollingBuffer: [AVAudioPCMBuffer] = []
    // Flag indicating event detection state
    var isTriggered = false
    // Audio snapshot taken at detection
    var preSnapshot: [AVAudioPCMBuffer] = []
    // Audio buffers collected after detection
    var postBuffers: [AVAudioPCMBuffer] = []
    // Accumulated duration of post-event buffers
    var postAccumulated: Double = 0.0
    
    // Audio frame size for each buffer tap
    let bufferSize = 2048
    // Seconds of audio to keep before trigger
    let preTriggerDuration: Double = 5.0
    // Seconds of audio to capture after trigger
    let postTriggerDuration: Double = 5.0
    
    // Indicates whether recording is active
    @Published var isRecording = false
    // Latest amplitude reading
    @Published var amplitude: Float = 0.0
    // Latest frequency reading
    @Published var frequency: Float = 0.0
    // File path of saved audio clip
    @Published var audioFilePath: String = ""
    
    // Convert linear amplitude to decibel scale
    var amplitudeDB: Float {
        amplitude <= 0 ? -100.0 : 20 * log10(amplitude)
    }
    
    // ML model for gunshot classification
    var soundClassifier: MLModel?
    // Queue for audio analysis tasks
    var analysisQueue = DispatchQueue(label: "SoundAnalysisQueue")
    // SoundAnalysis request object
    var request: SNClassifySoundRequest?
    // Analyzer for streaming audio analysis
    var analyzer: SNAudioStreamAnalyzer!
    // Observer for analysis results
    var resultsObserver = SoundResultsObserver()
    
    // Audio format for analysis based on detection mixer output
    lazy var streamFormat: AVAudioFormat = {
        return detectionMixer.avAudioNode.outputFormat(forBus: 0)
    }()
    
    // Initial setup: engine, permissions, and model loading
    init() {
        mic = engine.input!
        mixer = Mixer(mic)
        mixer.volume = 1.0
        detectionMixer = Mixer(mixer)
        detectionMixer.volume = 1.0
        engine.output = detectionMixer
        
        requestMicrophonePermission()        // Ask user for mic access
        setupAudioKit()                     // Configure pitch tracking

        // Load Core ML model for gunshot detection
        do {
            guard let modelURL = Bundle.main.url(
                forResource: "GunshotClassifier", withExtension: "mlmodelc"
            ) else {
                print("GunshotClassifier.mlmodelc not found in bundle.")
                return
            }

            let model = try MLModel(contentsOf: modelURL)
            soundClassifier = model

            request = try SNClassifySoundRequest(mlModel: model)
            analyzer = SNAudioStreamAnalyzer(format: streamFormat)
            try analyzer.add(request!, withObserver: resultsObserver)

            print("GunshotClassifier model loaded.")
        } catch {
            print("Failed to load or configure model: \(error)")
        }
    }

    // Request permission to record from microphone
    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance()
            .requestRecordPermission { granted in
                DispatchQueue.main.async {
                    print(granted ? "Microphone permission granted." : "Microphone permission denied.")
                }
            }
    }
    
    // Set up pitch tracker and log hardware audio format
    func setupAudioKit() {
        let hardwareFormat = mixer.avAudioNode.inputFormat(forBus: 0)
        print("Hardware sample rate: \(hardwareFormat.sampleRate), channels: \(hardwareFormat.channelCount)")
        
        // Initialize pitch and amplitude tracker
        tracker = PitchTap(mixer) { freqs, amps in
            DispatchQueue.main.async {
                self.frequency = freqs.first ?? 0.0
                self.amplitude = amps.first ?? 0.0
            }
        }
    }
    
    // Start audio engine, begin tracking, and install buffer tap
    func startRecording() {
        do {
            try engine.start()                // Start AudioKit engine
            tracker.start()                   // Start pitch tracker
            isRecording = true                // Update state
            print("AudioKit recording started. Engine running: \(engine.avEngine.isRunning)")
            
            detectionMixer.avAudioNode.removeTap(onBus: 0)  // Clear old taps
            detectionMixer.avAudioNode.installTap(
                onBus: 0,
                bufferSize: AVAudioFrameCount(bufferSize),
                format: nil
            ) { buffer, _ in
                self.analyzeAudio(buffer)     // Run classification
                self.storeAudioBuffer(buffer) // Manage buffers
            }

        } catch {
            print("Failed to start AudioKit: \(error.localizedDescription)")
        }
    }
    
    // Append buffer, trim old audio, and handle trigger logic
    func storeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        DispatchQueue.main.async {
            // Add new buffer to rolling buffer
            self.rollingBuffer.append(buffer)
            
            // Trim buffers to maintain pre-trigger duration limit
            var totalDuration = self.rollingBuffer.reduce(0.0) { sum, buf in
                sum + Double(buf.frameLength) / buf.format.sampleRate
            }
            while totalDuration > self.preTriggerDuration,
                  let first = self.rollingBuffer.first {
                totalDuration -= Double(first.frameLength) / first.format.sampleRate
                self.rollingBuffer.removeFirst()
            }
            
            // On detection, snapshot pre-event audio and start post capture
            if !self.isTriggered,
               self.resultsObserver.didDetectGunshotRecently {
                self.preSnapshot = self.rollingBuffer
                if let last = self.rollingBuffer.last, last === buffer {
                    self.rollingBuffer.removeLast()
                }
                self.isTriggered = true
                self.postBuffers = []
                self.postAccumulated = 0.0
                self.postBuffers.append(buffer)
                let dur = Double(buffer.frameLength) / buffer.format.sampleRate
                self.postAccumulated += dur
                return
            }
            
            // If triggered, accumulate post-event buffers
            if self.isTriggered {
                self.postBuffers.append(buffer)
                let dur = Double(buffer.frameLength) / buffer.format.sampleRate
                self.postAccumulated += dur
                
                // Once enough post-event audio collected, save clip
                if self.postAccumulated >= self.postTriggerDuration {
                    let combined = self.preSnapshot + self.postBuffers
                    self.saveGunshotClip(buffers: combined)
                    self.isTriggered = false
                    self.preSnapshot = []
                    self.postBuffers = []
                    self.postAccumulated = 0.0
                }
            }
        }
    }
    
    // Write combined buffers to audio file and notify listeners
    func saveGunshotClip(buffers: [AVAudioPCMBuffer]) {
        guard let firstBuffer = buffers.first else {
            print("No audio data to save.")
            return
        }
        let format = firstBuffer.format
        let fileManager = FileManager.default
        
        // Determine output file URL
        guard let documentsDirectory = fileManager
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first else {
            print("Unable to access document directory")
            return
        }
        
        let fileName = "gunshot_prePost_\(Date().timeIntervalSince1970).caf"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            // Create and write audio file
            let audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            for buf in buffers {
                try audioFile.write(from: buf)
            }
            print("Pre+Post clip saved at \(fileURL.path)")
            self.audioFilePath = fileURL.path
            
            // Notify other components of detection
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("DetectionOccurred"),
                    object: nil,
                    userInfo: [
                        "timestamp": Date(),
                        "result": self.resultsObserver.lastResult,
                        "confidence": self.resultsObserver.lastConfidence
                    ]
                )
            }
        } catch {
            print("Error saving clip: \(error)")
        }
    }

    // Stop recording, remove taps, and reset engine state
    func stopRecording() {
        detectionMixer.avAudioNode.removeTap(onBus: 0)
        tracker.stop()
        engine.stop()
        engine.avEngine.reset()
        isRecording = false
        print("AudioKit recording stopped.")
    }

    // Toggle recording on or off
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // Analyze buffer for classification on background queue
    func analyzeAudio(_ buffer: AVAudioPCMBuffer) {
        analysisQueue.async {
            self.analyzer.analyze(buffer, atAudioFramePosition: AVAudioFramePosition(0))
        }
    }
}

// Observes SoundAnalysis results and tracks gunshot detections
class SoundResultsObserver: NSObject, SNResultsObserving {
    var didDetectGunshotRecently = false
    var lastResult: String = ""
    var lastConfidence: Double = 0.0

    // Handle classification results produced by SoundAnalysis
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }

        if let topResult = classificationResult.classifications.first,
           topResult.identifier == "gunshot",
           topResult.confidence > 0.8 {
            didDetectGunshotRecently = true
            self.lastResult = topResult.identifier
            self.lastConfidence = topResult.confidence
            
            // Reset detection flag after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.didDetectGunshotRecently = false
            }

            print("Gunshot detected with Core ML! Confidence: \(topResult.confidence)")
        }
    }
}
