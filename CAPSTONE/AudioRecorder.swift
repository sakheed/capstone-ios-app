import Foundation
import AVFoundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import SoundAnalysis

class AudioRecorder: ObservableObject {
    var engine = AudioEngine()
    var mic: AudioEngine.InputNode
    var mixer: Mixer         // Used for PitchTap (frequency/amplitude)
    var detectionMixer: Mixer // Used for gunshot detection tap
    var tracker: PitchTap!
    
    // Rolling buffer for pre-trigger audio (holds the last 5 seconds)
    var rollingBuffer: [AVAudioPCMBuffer] = []
    
    // Variables for post-trigger capture
    var isTriggered: Bool = false
    var postTriggerBuffers: [AVAudioPCMBuffer] = []
    var postTriggerAccumulatedDuration: Double = 0.0
    
    let bufferSize = 2048
    
    // Parameters for gunshot detection
    let preTriggerDuration: Double = 5.0       // seconds to keep before the trigger
    let postTriggerDuration: Double = 5.0      // seconds to capture after the trigger
    let triggerThreshold: Float = 0.4          // amplitude threshold for a loud sound (for testing)
    
    @Published var isRecording = false
    @Published var amplitude: Float = 0.0
    @Published var frequency: Float = 0.0
    
    // Computed property for decibel conversion.
    var amplitudeDB: Float {
        if amplitude <= 0 { return -100.0 }
        else { return 20 * log10(amplitude) }
    }
    
    init() {
        mic = engine.input!
        // Create a mixer for PitchTap.
        mixer = Mixer(mic)
        mixer.volume = 1.0
        // Create a second mixer for gunshot detection, taking input from the first mixer.
        detectionMixer = Mixer(mixer)
        detectionMixer.volume = 1.0
        
        // Route the engine output to the detection mixer.
        engine.output = detectionMixer
        
        requestMicrophonePermission()
        setupAudioKit()
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
        
        // Set up PitchTap on the first mixer.
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
            
            // Install a tap on the detectionMixer for gunshot detection.
            detectionMixer.avAudioNode.removeTap(onBus: 0)
            detectionMixer.avAudioNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: nil) { buffer, time in
                self.storeAudioBuffer(buffer)
            }
        } catch {
            print("❌ Failed to start AudioKit: \(error.localizedDescription)")
        }
    }
    
    func storeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        DispatchQueue.main.async {
            // Append new buffer to the rollingBuffer.
            self.rollingBuffer.append(buffer)
            
            // Trim rollingBuffer to only keep the last preTriggerDuration seconds.
            var totalPreDuration = self.rollingBuffer.reduce(0.0) { sum, buf in
                sum + Double(buf.frameLength) / buf.format.sampleRate
            }
            while totalPreDuration > self.preTriggerDuration, let first = self.rollingBuffer.first {
                totalPreDuration -= Double(first.frameLength) / first.format.sampleRate
                self.rollingBuffer.removeFirst()
            }
            
            // Check for trigger condition.
            if !self.isTriggered && self.amplitude > self.triggerThreshold {
                self.isTriggered = true
                self.postTriggerBuffers = []          // Reset post-trigger buffers.
                self.postTriggerAccumulatedDuration = 0.0
                print("Gunshot detected! Amp: \(self.amplitude) exceeds threshold: \(self.triggerThreshold)")
            }
            
            // If triggered, accumulate post-trigger buffers.
            if self.isTriggered {
                self.postTriggerBuffers.append(buffer)
                let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
                self.postTriggerAccumulatedDuration += bufferDuration
                
                if self.postTriggerAccumulatedDuration >= self.postTriggerDuration {
                    let combinedBuffers = self.rollingBuffer + self.postTriggerBuffers
                    self.saveGunshotClip(buffers: combinedBuffers)
                    self.isTriggered = false
                    self.postTriggerBuffers = []
                    self.postTriggerAccumulatedDuration = 0.0
                }
            }
        }
    }
    
    func saveGunshotClip(buffers: [AVAudioPCMBuffer]) {
        guard let firstBuffer = buffers.first else {
            print("No audio data to save for gunshot clip.")
            return
        }
        let format = firstBuffer.format
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access the document directory")
            return
        }
        let fileName = "gunshot_\(Date().timeIntervalSince1970).caf"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL,
                                            settings: format.settings,
                                            commonFormat: format.commonFormat,
                                            interleaved: format.isInterleaved)
            for buffer in buffers {
                try audioFile.write(from: buffer)
            }
            print("Gunshot clip saved at \(fileURL.path)")
        } catch {
            print("Error saving gunshot clip: \(error)")
        }
    }
    
    func stopRecording() {
        detectionMixer.avAudioNode.removeTap(onBus: 0)
        tracker.stop()
        engine.stop()
        isRecording = false
        print("🎤 AudioKit recording stopped.")
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
