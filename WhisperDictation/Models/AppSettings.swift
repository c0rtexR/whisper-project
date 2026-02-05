import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("selectedModel") var selectedModel: String = "large-v3"
    @AppStorage("hotkey") var hotkey: Int = 57 // CapsLock keycode
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = true
    @AppStorage("recordingMode") var recordingMode: RecordingMode = .toggle
    @AppStorage("showVisualFeedback") var showVisualFeedback: Bool = true
    @AppStorage("playAudioFeedback") var playAudioFeedback: Bool = false
    @AppStorage("hasCompletedSetup") var hasCompletedSetup: Bool = false
    @AppStorage("useLLMCorrection") var useLLMCorrection: Bool = false
    @AppStorage("llmModel") var llmModel: String = "qwen2.5-0.5b-instruct-q4_0.gguf"
    @AppStorage("writingStyle") var writingStyle: WritingStyle = .none
    @AppStorage("autoCheckForUpdates") var autoCheckForUpdates: Bool = true
    @AppStorage("lastUpdateCheckDate") var lastUpdateCheckDate: Double = 0
    @Published var modelRefreshTrigger: Bool = false

    var modelsDirectory: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if app support is not available
            return FileManager.default.temporaryDirectory.appendingPathComponent("WhisperDictation/models")
        }
        let modelsDir = appSupport.appendingPathComponent("WhisperDictation/models")
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }

    func isModelDownloaded(_ modelName: String) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(modelName).path)
    }

    func modelPath(_ modelName: String) -> URL {
        modelsDirectory.appendingPathComponent("ggml-\(modelName).bin")
    }

    func isLLMModelDownloaded(_ modelName: String) -> Bool {
        let path = modelsDirectory.appendingPathComponent(modelName)
        return FileManager.default.fileExists(atPath: path.path)
    }

    func llmModelPath(_ modelName: String) -> URL {
        modelsDirectory.appendingPathComponent(modelName)
    }
}

enum RecordingMode: String, CaseIterable, Codable {
    case toggle = "Toggle"
    case holdToRecord = "Hold to Record"

    var description: String {
        switch self {
        case .toggle: return "Press once to start, again to stop"
        case .holdToRecord: return "Hold key to record, release to stop"
        }
    }
}

enum WritingStyle: String, CaseIterable, Codable {
    case none = "None"
    case professional = "Professional"
    case casual = "Casual"
    case funny = "Funny"

    var description: String {
        switch self {
        case .none: return "Basic error correction only"
        case .professional: return "Formal business language"
        case .casual: return "Conversational and friendly"
        case .funny: return "Humorous, Bender-style"
        }
    }

    var number: Int {
        switch self {
        case .none: return 1
        case .professional: return 2
        case .casual: return 3
        case .funny: return 4
        }
    }

    func next() -> WritingStyle {
        switch self {
        case .none: return .professional
        case .professional: return .casual
        case .casual: return .funny
        case .funny: return .none
        }
    }
}
