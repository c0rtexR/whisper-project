import Foundation

struct TranscriptionItem: Identifiable, Codable {
    let id: UUID
    let whisperText: String
    let llmText: String?
    let timestamp: Date

    init(whisperText: String, llmText: String? = nil) {
        self.id = UUID()
        self.whisperText = whisperText
        self.llmText = llmText
        self.timestamp = Date()
    }

    // Computed property for backward compatibility
    var text: String {
        llmText ?? whisperText
    }

    // Custom decoding to handle old format with "text" field
    enum CodingKeys: String, CodingKey {
        case id, whisperText, llmText, timestamp, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        // Try new format first
        if let whisper = try? container.decode(String.self, forKey: .whisperText) {
            whisperText = whisper
            llmText = try? container.decode(String.self, forKey: .llmText)
        } else {
            // Fall back to old format with "text" field
            whisperText = try container.decode(String.self, forKey: .text)
            llmText = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(whisperText, forKey: .whisperText)
        try container.encodeIfPresent(llmText, forKey: .llmText)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

class TranscriptionHistory: ObservableObject {
    static let shared = TranscriptionHistory()

    @Published var items: [TranscriptionItem] = []
    private let maxItems = 10
    private let storageKey = "transcriptionHistory"

    init() {
        loadHistory()
    }

    func addTranscription(whisperText: String, llmText: String? = nil) {
        let item = TranscriptionItem(whisperText: whisperText, llmText: llmText)
        print("📚 Adding transcription - whisperText: '\(whisperText)', llmText: '\(llmText ?? "nil")'")
        items.insert(item, at: 0)

        // Keep only the last maxItems
        if items.count > maxItems {
            items.removeLast()
        }

        saveHistory()
    }

    func clearHistory() {
        items.removeAll()
        saveHistory()
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TranscriptionItem].self, from: data) {
            items = decoded
        }
    }
}
