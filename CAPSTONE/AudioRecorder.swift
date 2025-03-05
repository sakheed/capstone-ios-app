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
    
    // Accumulate buffers for the current 30-second chunk.
    var currentChunk: [AVAudioPCMBuffer] = []
    // Array to hold finalized fixed chunks.
    var fixedChunks: [[AVAudioPCMBuffer]] = []
    
    let bufferSize = 2048

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
        let hardwareFormat = mic.avAudioNode.inputFormat(forBus: 0)
        print("🎤 Hardware sample rate: \(hardwareFormat.sampleRate), channels: \(hardwareFormat.channelCount)")
        
        tracker = PitchTap(mic) { freqs, amps in
            DispatchQueue.main.async {
                self.frequency = freqs.first ?? 0.0
                self.amplitude = amps.first ?? 0.0
            }
        }
        
        // Dummy output to keep the engine happy.
        let silence = Fader(mic, gain: 0)
        engine.output = silence
    }
    
    func startRecording() {
        do {
            try engine.start()
            tracker.start()
            isRecording = true
            print("🎤 Engine running? \(engine.avEngine.isRunning)")
            print("🎤 AudioKit recording started.")
            
            // Remove any existing tap to avoid conflicts.
            mic.avAudioNode.removeTap(onBus: 0)
            // Let the system choose the native format by passing nil.
            mic.avAudioNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: nil) { (buffer, time) in
                self.storeAudioBuffer(buffer)
            }
        } catch {
            print("❌ Failed to start AudioKit: \(error.localizedDescription)")
        }
    }
    
    func storeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        DispatchQueue.main.async {
            // Append the new buffer to the current chunk.
            self.currentChunk.append(buffer)
            
            // Calculate the total duration of the current chunk.
            let totalDuration = self.currentChunk.reduce(0.0) { (sum, buf) -> Double in
                sum + Double(buf.frameLength) / buf.format.sampleRate
            }
            
            // If we've accumulated 30 seconds (or more), finalize this chunk.
            if totalDuration >= 30.0 {
                print("✅ Fixed 30-second chunk saved! Total duration: \(totalDuration) seconds.")
                self.fixedChunks.append(self.currentChunk)
                self.currentChunk = []  // Start a new chunk.
            }
        }
    }
    
    func stopRecording() {
        mic.avAudioNode.removeTap(onBus: 0)
        tracker.stop()
        engine.stop()
        isRecording = false
        print("⏹️ AudioKit recording stopped.")
        
        // Print the duration of the last (unfinished) chunk.
        let finalDuration = currentChunk.reduce(0.0) { (sum, buf) -> Double in
            sum + Double(buf.frameLength) / buf.format.sampleRate
        }
        print("Final incomplete chunk duration: \(finalDuration) seconds.")
        
        // Save all fixed chunks to separate files (if desired).
        saveAllFixedChunks()
        
        // Combine all fixed chunks (and any remaining current chunk) into one seamless file.
        combineAndSaveChunks()
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // Optionally, retrieve all fixed chunks.
    func getFixedChunks() -> [[AVAudioPCMBuffer]] {
        return fixedChunks
    }
    
    // MARK: - Saving Individual Chunks
    
    /// Save a single fixed chunk to a file.
    func saveChunkToFile(chunk: [AVAudioPCMBuffer], fileName: String) {
        guard let firstBuffer = chunk.first else {
            print("No audio data to save!")
            return
        }
        let format = firstBuffer.format
        
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access the document directory")
            return
        }
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            let audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            for buffer in chunk {
                try audioFile.write(from: buffer)
            }
            print("Saved chunk to file at \(fileURL.path)")
        } catch {
            print("Error saving audio file: \(error)")
        }
    }
    
    /// Save all fixed chunks individually.
    func saveAllFixedChunks() {
        for (index, chunk) in fixedChunks.enumerated() {
            let fileName = "fixedChunk_\(index).caf"
            saveChunkToFile(chunk: chunk, fileName: fileName)
        }
    }
    
    // MARK: - Combining Chunks into One Seamless File
    
    /// Combine all fixed chunks and any leftover current chunk into one seamless audio file.
    func combineAndSaveChunks() {
        // Flatten fixed chunks into one array of buffers.
        var allBuffers: [AVAudioPCMBuffer] = []
        for chunk in fixedChunks {
            allBuffers.append(contentsOf: chunk)
        }
        // Optionally include any unfinished current chunk.
        if !currentChunk.isEmpty {
            allBuffers.append(contentsOf: currentChunk)
        }
        
        guard let firstBuffer = allBuffers.first else {
            print("No audio data to combine.")
            return
        }
        let format = firstBuffer.format
        
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access the document directory")
            return
        }
        let fileURL = documentsDirectory.appendingPathComponent("combinedAudio.caf")
        
        do {
            let audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            for buffer in allBuffers {
                try audioFile.write(from: buffer)
            }
            print("Combined audio file saved at \(fileURL.path)")
        } catch {
            print("Error combining and saving audio file: \(error)")
        }
    }
}
