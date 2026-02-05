import Foundation
import AVFoundation

// This is a Swift wrapper around whisper.cpp
// The actual C++ integration will be done via a bridging header
class WhisperService {
    private var context: OpaquePointer?
    private let queue = DispatchQueue(label: "com.whisperdictation.whisper", qos: .userInitiated)

    func loadModel(at path: URL) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file not found"])
        }

        // Use async to avoid potential deadlock - calling code already dispatches to background
        var loadedContext: OpaquePointer?
        queue.sync {
            // Initialize whisper context with Metal support
            // This will call whisper.cpp C functions via bridging header
            var params = whisper_context_default_params()
            params.use_gpu = true // Enable Metal acceleration

            loadedContext = whisper_init_from_file_with_params(path.path, params)
        }

        guard let loadedContext = loadedContext else {
            throw NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize Whisper model"])
        }

        context = loadedContext
    }

    func transcribe(audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self, let context = self.context else {
                completion(.failure(NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Whisper not initialized"])))
                return
            }

            // Load audio file and convert to samples
            guard let audioData = self.loadAudioSamples(from: audioURL) else {
                completion(.failure(NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load audio"])))
                return
            }

            // Set up transcription parameters
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_progress = false
            params.print_special = false
            params.print_realtime = false
            params.print_timestamps = false

            let selectedLang = AppSettings.shared.selectedLanguage
            if selectedLang == "auto" {
                let languagePtr = strdup("auto")
                params.language = UnsafePointer(languagePtr)
                defer { free(languagePtr) }
                params.detect_language = true
            } else {
                let languagePtr = strdup(selectedLang)
                params.language = UnsafePointer(languagePtr)
                defer { free(languagePtr) }
            }

            params.n_threads = 4
            params.offset_ms = 0
            params.no_context = true
            params.single_segment = false

            // Run transcription
            let result = audioData.withUnsafeBufferPointer { buffer in
                whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
            }

            guard result == 0 else {
                completion(.failure(NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transcription failed"])))
                return
            }

            // Extract transcribed text
            let segmentCount = whisper_full_n_segments(context)
            var transcription = ""

            for i in 0..<segmentCount {
                if let cString = whisper_full_get_segment_text(context, i) {
                    transcription += String(cString: cString)
                }
            }

            let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(.success(trimmed))
        }
    }

    private func loadAudioSamples(from url: URL) -> [Float]? {
        // Load WAV file and convert to Float32 samples at 16kHz
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            print("Failed to open audio file: \(url.path)")
            return nil
        }

        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("Failed to create audio buffer")
            return nil
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            print("Failed to read audio file: \(error.localizedDescription)")
            return nil
        }

        guard let floatData = buffer.floatChannelData else {
            print("No audio channel data available")
            return nil
        }

        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))
        return samples
    }

    func transcribeChunk(samples: [Float], completion: @escaping (Result<String, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self, let context = self.context else {
                completion(.failure(NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Whisper not initialized"])))
                return
            }

            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_progress = false
            params.print_special = false
            params.print_realtime = false
            params.print_timestamps = false
            params.single_segment = true
            params.no_context = true
            params.n_threads = 4

            let selectedLang = AppSettings.shared.selectedLanguage
            if selectedLang == "auto" {
                let languagePtr = strdup("auto")
                params.language = UnsafePointer(languagePtr)
                defer { free(languagePtr) }
                params.detect_language = true
            } else {
                let languagePtr = strdup(selectedLang)
                params.language = UnsafePointer(languagePtr)
                defer { free(languagePtr) }
            }

            let result = samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
            }

            guard result == 0 else {
                completion(.failure(NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Chunk transcription failed"])))
                return
            }

            let segmentCount = whisper_full_n_segments(context)
            var transcription = ""
            for i in 0..<segmentCount {
                if let cString = whisper_full_get_segment_text(context, i) {
                    transcription += String(cString: cString)
                }
            }

            completion(.success(transcription.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }

    func unloadModel() {
        queue.sync {
            if let context = context {
                whisper_free(context)
                self.context = nil
            }
        }
    }

    deinit {
        unloadModel()
    }
}

// NOTE: The whisper.cpp C functions are imported via WhisperBridge.h bridging header
// These include: whisper_context_default_params, whisper_init_from_file_with_params,
// whisper_full_default_params, whisper_full, whisper_full_n_segments,
// whisper_full_get_segment_text, whisper_free, and related structs/constants
