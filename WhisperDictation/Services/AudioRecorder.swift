import Foundation
import AVFoundation

class AudioRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    var isRecording: Bool {
        audioEngine?.isRunning ?? false
    }

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "whisper-recording-\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

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

            do {
                try audioFile.write(from: convertedBuffer)
            } catch {
                print("Failed to write audio data: \(error.localizedDescription)")
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

        return url
    }

    func cleanup() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
