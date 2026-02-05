import Foundation

struct WhisperModel: Identifiable, Codable {
    let id: String
    let name: String
    let size: String
    let downloadURL: String
    let description: String
    let estimatedRAM: String

    static let availableModels: [WhisperModel] = [
        WhisperModel(
            id: "tiny.en",
            name: "Tiny",
            size: "75 MB",
            downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin",
            description: "Fastest, less accurate",
            estimatedRAM: "~390 MB"
        ),
        WhisperModel(
            id: "base.en",
            name: "Base",
            size: "142 MB",
            downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin",
            description: "Fast, decent accuracy",
            estimatedRAM: "~500 MB"
        ),
        WhisperModel(
            id: "small.en",
            name: "Small",
            size: "466 MB",
            downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin",
            description: "Good balance",
            estimatedRAM: "~1.0 GB"
        ),
        WhisperModel(
            id: "medium.en",
            name: "Medium",
            size: "1.5 GB",
            downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin",
            description: "High accuracy",
            estimatedRAM: "~2.6 GB"
        ),
        WhisperModel(
            id: "large-v3",
            name: "Large V3",
            size: "3.1 GB",
            downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin",
            description: "Best accuracy (recommended)",
            estimatedRAM: "~4.7 GB"
        )
    ]
}
