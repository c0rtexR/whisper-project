import Foundation

enum TranscriptionState {
    case idle
    case recording
    case processing
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Transcribing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
