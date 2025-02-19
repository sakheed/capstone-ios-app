import Foundation
import AVFoundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import SoundAnalysis

class AudioRecorder: ObservableObject {
    var engine = AudioEngine()
    var mic: AudioEngine.InputNode
    var tracker: PitchTap!
    
    @Published var isRecording = false
    @Published var amplitude: Float = 0.0
    @Published var frequency: Float = 0.0
    
    init() {
        mic = engine.input!
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
        tracker = PitchTap(mic) { freqs, amps in
            DispatchQueue.main.async {
                self.frequency = freqs.first ?? 0.0
                self.amplitude = amps.first ?? 0.0
            }
        }
        
        // Add a "dummy" output to prevent engine error
        let silence = Fader(mic, gain: 0)
        engine.output = silence
    }
    
    func startRecording() {
        do {
            try engine.start()
            tracker.start()
            isRecording = true
            print("🎤 AudioKit recording started.")
        } catch {
            print("❌ Failed to start AudioKit: \(error)")
        }
    }
    
    func stopRecording() {
        tracker.stop()
        engine.stop()
        isRecording = false
        print("⏹️ AudioKit recording stopped.")
    }
    
    // New toggle method to switch between start and stop
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
