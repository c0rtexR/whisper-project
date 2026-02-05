import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    @Published var audioLevel: Float = 0.0

    // Buffer for streaming transcription
    private var audioSamplesBuffer: [Float] = []
    private let bufferLock = NSLock()

    var isRecording: Bool {
        audioEngine?.isRunning ?? false
    }

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "whisper-recording-\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Clear samples buffer
        bufferLock.lock()
        audioSamplesBuffer.removeAll()
        bufferLock.unlock()

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Whisper expects 16kHz mono
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"])
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        let audioFile = try AVAudioFile(forWriting: fileURL, settings: outputFormat.settings)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Compute RMS audio level from input buffer
            if let channelData = buffer.floatChannelData {
                let frames = Int(buffer.frameLength)
                var sum: Float = 0.0
                for i in 0..<frames {
                    let sample = channelData[0][i]
                    sum += sample * sample
                }
                let rms = sqrt(sum / Float(max(frames, 1)))
                // Normalize to 0.0-1.0 range (typical speech RMS is 0.01-0.3)
                let normalized = min(rms * 5.0, 1.0)
                DispatchQueue.main.async {
                    self.audioLevel = normalized
                }
            }

            let inputCallback: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)
            ) else {
                print("Failed to create converted audio buffer")
                return
            }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)

            if status == .error {
                print("Conversion error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            // Write to file
            do {
                try audioFile.write(from: convertedBuffer)
            } catch {
                print("Failed to write audio data: \(error.localizedDescription)")
            }

            // Append to samples buffer for streaming transcription
            if let floatData = convertedBuffer.floatChannelData {
                let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(convertedBuffer.frameLength)))
                self.bufferLock.lock()
                self.audioSamplesBuffer.append(contentsOf: samples)
                self.bufferLock.unlock()
            }
        }

        try audioEngine.start()

        self.audioEngine = audioEngine
        self.audioFile = audioFile
        self.recordingURL = fileURL

        return fileURL
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()

        let url = recordingURL
        audioEngine = nil
        audioFile = nil
        recordingURL = nil

        DispatchQueue.main.async {
            self.audioLevel = 0.0
        }

        // Clear samples buffer
        bufferLock.lock()
        audioSamplesBuffer.removeAll()
        bufferLock.unlock()

        return url
    }

    /// Returns the current audio samples (last ~10 seconds max at 16kHz)
    func getCurrentAudioSamples() -> [Float] {
        bufferLock.lock()
        let maxSamples = 16000 * 10  // 10 seconds at 16kHz
        let samples: [Float]
        if audioSamplesBuffer.count > maxSamples {
            samples = Array(audioSamplesBuffer.suffix(maxSamples))
        } else {
            samples = audioSamplesBuffer
        }
        bufferLock.unlock()
        return samples
    }

    func cleanup() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
