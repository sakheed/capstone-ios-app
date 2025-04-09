import Foundation
import AVFoundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import SoundAnalysis

import CoreML



class AudioRecorder: ObservableObject {
    var engine = AudioEngine()
    var mic: AudioEngine.InputNode
    
    var mixer: Mixer         // For PitchTap (frequency/amplitude)
    var detectionMixer: Mixer // For installing a tap
    
    var tracker: PitchTap!
    
    // Rolling buffer for up to 5 seconds of pre‑event audio
    var rollingBuffer: [AVAudioPCMBuffer] = []
    
    // Post-event capture
    var isTriggered = false
    var preSnapshot: [AVAudioPCMBuffer] = []
    var postBuffers: [AVAudioPCMBuffer] = []
    var postAccumulated: Double = 0.0
    
    // Buffer/timing parameters
    let bufferSize = 2048
    let preTriggerDuration: Double = 5.0
    let postTriggerDuration: Double = 5.0
    
    @Published var isRecording = false
    @Published var amplitude: Float = 0.0
    @Published var frequency: Float = 0.0
    
    // Convert raw amplitude to dB for UI
    var amplitudeDB: Float {
        amplitude <= 0 ? -100.0 : 20 * log10(amplitude)
    }
    
    var soundClassifier: MLModel?
    var analysisQueue = DispatchQueue(label: "SoundAnalysisQueue")
    var request: SNClassifySoundRequest?
    var analyzer: SNAudioStreamAnalyzer!
    var resultsObserver = SoundResultsObserver()
    
    // Create a stream format matching mic input
    lazy var streamFormat: AVAudioFormat = {
        return detectionMixer.avAudioNode.outputFormat(forBus: 0)
    }()
    
    init() {
        mic = engine.input!
        mixer = Mixer(mic)
        mixer.volume = 1.0
        detectionMixer = Mixer(mixer)
        detectionMixer.volume = 1.0
        engine.output = detectionMixer
        
        requestMicrophonePermission()
        setupAudioKit()

        // ✅ Safe model load
        do {
            guard let modelURL = Bundle.main.url(forResource: "GunshotClassifier", withExtension: "mlmodelc") else {
                print("❌ GunshotClassifier.mlmodelc not found in bundle.")
                return
            }

            let model = try MLModel(contentsOf: modelURL)
            soundClassifier = model

            request = try SNClassifySoundRequest(mlModel: model)
            analyzer = SNAudioStreamAnalyzer(format: streamFormat)
            try analyzer.add(request!, withObserver: resultsObserver)

            print("✅ GunshotClassifier model loaded.")
        } catch {
            print("❌ Failed to load or configure model: \(error)")
        }
    }

    
    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Microphone permission granted.")
                } else {
                    print("❌ Microphone permission denied.")
                }
            }
        }
    }
    
    func setupAudioKit() {
        let hardwareFormat = mixer.avAudioNode.inputFormat(forBus: 0)
        print("🎤 Hardware sample rate: \(hardwareFormat.sampleRate), channels: \(hardwareFormat.channelCount)")
        
        // PitchTap to track frequency & amplitude
        tracker = PitchTap(mixer) { freqs, amps in
            DispatchQueue.main.async {
                self.frequency = freqs.first ?? 0.0
                self.amplitude = amps.first ?? 0.0
            }
        }
    }
    
    func startRecording() {
        do {
            try engine.start()
            tracker.start()
            isRecording = true
            print("🎤 AudioKit recording started. Engine running: \(engine.avEngine.isRunning)")
            
            // Remove old tap, then install a new tap on detectionMixer
            detectionMixer.avAudioNode.removeTap(onBus: 0)
            detectionMixer.avAudioNode.installTap(
                onBus: 0,
                bufferSize: AVAudioFrameCount(bufferSize),
                format: nil
            ) { buffer, time in
                self.analyzeAudio(buffer)
                self.storeAudioBuffer(buffer)
            }

        } catch {
            print("❌ Failed to start AudioKit: \(error.localizedDescription)")
        }
    }
    
    func storeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        DispatchQueue.main.async {
            // 1) Always append the new buffer to rollingBuffer
            self.rollingBuffer.append(buffer)
            
            // 2) Trim rollingBuffer to ~5 seconds
            var totalDuration = self.rollingBuffer.reduce(0.0) { sum, buf in
                sum + Double(buf.frameLength) / buf.format.sampleRate
            }
            while totalDuration > self.preTriggerDuration, let first = self.rollingBuffer.first {
                totalDuration -= Double(first.frameLength) / first.format.sampleRate
                self.rollingBuffer.removeFirst()
            }
            
            // 3) If not triggered yet, check amplitude for event
            if !self.isTriggered,
               self.resultsObserver.didDetectGunshotRecently {

                
                // a) Snapshot the rolling buffer as "pre"
                self.preSnapshot = self.rollingBuffer
                
                // b) Remove the current buffer from rollingBuffer so we don't double-include it
                if let last = self.rollingBuffer.last, last === buffer {
                    self.rollingBuffer.removeLast()
                }
                
                // c) Start post capture
                self.isTriggered = true
                self.postBuffers = []
                self.postAccumulated = 0.0
                
                // d) The entire "event" buffer is considered post
                self.postBuffers.append(buffer)
                let dur = Double(buffer.frameLength) / buffer.format.sampleRate
                self.postAccumulated += dur
                
                return
            }
            
            // 4) If triggered, accumulate post buffers
            if self.isTriggered {
                self.postBuffers.append(buffer)
                let dur = Double(buffer.frameLength) / buffer.format.sampleRate
                self.postAccumulated += dur
                
                // 5) Once we have 5 seconds of post, combine & save
                if self.postAccumulated >= self.postTriggerDuration {
                    // Combine pre + post
                    let combined = self.preSnapshot + self.postBuffers
                    self.saveGunshotClip(buffers: combined)
                    // Reset
                    self.isTriggered = false
                    self.preSnapshot = []
                    self.postBuffers = []
                    self.postAccumulated = 0.0
                }
            }
        }
    }
    
    func saveGunshotClip(buffers: [AVAudioPCMBuffer]) {
        guard let firstBuffer = buffers.first else {
            print("No audio data to save.")
            return
        }
        let format = firstBuffer.format
        let fileManager = FileManager.default
        
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access document directory")
            return
        }
        
        let fileName = "gunshot_prePost_\(Date().timeIntervalSince1970).caf"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
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
            
            // Post a notification so that the sensor snapshot can be captured.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("DetectionOccurred"), object: nil, userInfo: ["timestamp": Date()])
            }
            
        } catch {
            print("Error saving clip: \(error)")
        }
    }

    
    func stopRecording() {
        detectionMixer.avAudioNode.removeTap(onBus: 0)
        tracker.stop()
        
        engine.stop()
        engine.avEngine.reset()

        
        isRecording = false
        print("⏹️ AudioKit recording stopped.")
    }

    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func analyzeAudio(_ buffer: AVAudioPCMBuffer) {
        analysisQueue.async {
            self.analyzer.analyze(buffer, atAudioFramePosition: AVAudioFramePosition(0))
        }
    }

}

class SoundResultsObserver: NSObject, SNResultsObserving {
    var didDetectGunshotRecently = false

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }

        if let topResult = classificationResult.classifications.first, topResult.identifier == "gunshot", topResult.confidence > 0.8 {
            didDetectGunshotRecently = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.didDetectGunshotRecently = false
            }

            print("🔫 Gunshot detected with Core ML! Confidence: \(topResult.confidence)")
        }
    }
    
}
