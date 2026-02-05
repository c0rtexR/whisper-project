import Foundation

struct LLMModel: Identifiable {
    let id: String
    let name: String
    let size: String
    let downloadURL: String
    let description: String

    static let availableModels: [LLMModel] = [
        LLMModel(
            id: "qwen2.5-0.5b-instruct-q4_0.gguf",
            name: "Qwen2.5 0.5B",
            size: "350 MB",
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_0.gguf",
            description: "Fastest, basic corrections only"
        ),
        LLMModel(
            id: "qwen2.5-1.5b-instruct-q4_0.gguf",
            name: "Qwen2.5 1.5B",
            size: "950 MB",
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_0.gguf",
            description: "Fast, struggles with style rewriting"
        ),
        LLMModel(
            id: "llama-3.2-1b-instruct-q4_0.gguf",
            name: "Llama 3.2 1B",
            size: "650 MB",
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            description: "Fast, struggles with style rewriting"
        ),
        LLMModel(
            id: "qwen2.5-3b-instruct-q4_0.gguf",
            name: "Qwen2.5 3B (Recommended)",
            size: "1.9 GB",
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_0.gguf",
            description: "Good quality style rewriting, still fast"
        ),
        LLMModel(
            id: "llama-3.2-3b-instruct-q4_k_m.gguf",
            name: "Llama 3.2 3B",
            size: "1.9 GB",
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            description: "Good quality, better instruction following"
        ),
        LLMModel(
            id: "qwen2.5-7b-instruct-q4_k_m.gguf",
            name: "Qwen2.5 7B",
            size: "4.7 GB",
            downloadURL: "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf",
            description: "Excellent quality, slower (needs 8GB+ RAM)"
        )
    ]
}
