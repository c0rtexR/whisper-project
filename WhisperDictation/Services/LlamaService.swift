import Foundation

class LlamaService {
    private var serverProcess: Process?
    private var modelPath: URL?
    private let serverPort = 8765  // Use custom port to avoid conflicts
    private var serverURL: URL {
        URL(string: "http://localhost:\(serverPort)/completion")!
    }

    private var llamaServerPath: String {
        // Look for bundled llama-server in app bundle Resources folder
        if let resourcePath = Bundle.main.resourcePath {
            let bundledPath = resourcePath + "/llama-server"
            if FileManager.default.fileExists(atPath: bundledPath) {
                return bundledPath
            }
        }
        // Fallback to development path
        return "/Users/patrykolejniczakorlowski/Development/whisper/llama.cpp/build/bin/llama-server"
    }

    func loadModel(at path: URL) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw NSError(domain: "LlamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file not found"])
        }

        modelPath = path

        // Start llama-server in background
        let process = Process()
        process.executableURL = URL(fileURLWithPath: llamaServerPath)
        process.arguments = [
            "-m", path.path,
            "--port", String(serverPort),
            "-c", "2048",      // Context size
            "-ngl", "99",      // GPU layers
            "-t", "4",         // Threads
            "--log-disable",   // Disable verbose logging
            "--log-file", "/dev/null"  // Redirect all logs to /dev/null
        ]

        // Redirect ALL output to /dev/null
        let devNull = FileHandle(forWritingAtPath: "/dev/null")
        process.standardOutput = devNull
        process.standardError = devNull
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
            serverProcess = process

            print("🔄 Starting LLM server on port \(serverPort)...")

            // Wait for server to be ready (model loading can take several seconds)
            var attempts = 0
            let maxAttempts = 30  // 15 seconds max wait
            var serverReady = false

            while attempts < maxAttempts && !serverReady {
                Thread.sleep(forTimeInterval: 0.5)
                attempts += 1

                // Try to connect to health endpoint
                if let url = URL(string: "http://localhost:\(serverPort)/health"),
                   let data = try? Data(contentsOf: url),
                   let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   response["status"] as? String == "ok" {
                    serverReady = true
                }
            }

            if serverReady {
                print("✅ LLM server ready - model is HOT in memory!")
            } else {
                print("⚠️ LLM server started but health check timed out")
            }
        } catch {
            throw NSError(domain: "LlamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start llama-server: \(error)"])
        }
    }

    func correctText(_ text: String, style: WritingStyle, completion: @escaping (Result<String, Error>) -> Void) {
        guard serverProcess != nil else {
            completion(.failure(NSError(domain: "LlamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "LLM server not running"])))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let prompt: String
            let stopTokens: [String]

            switch style {
            case .none:
                prompt = "Correct: \(text)"
                stopTokens = ["\n"]
            case .professional:
                prompt = """
                Translate from casual to professional business English (maintain the exact same question or statement):

                Casual: Should we grab lunch?
                Professional: Would you be available for a lunch meeting?

                Casual: hey the meeting is at 3pm
                Professional: The meeting is scheduled for 3:00 PM.

                Casual: \(text)
                Professional:
                """
                stopTokens = ["\n\n", "\nCasual:"]
            case .casual:
                prompt = """
                Translate from formal to casual English (maintain the exact same question or statement):

                Formal: Should we proceed with the project?
                Casual: Wanna move forward with the project?

                Formal: I would like to request your assistance.
                Casual: Hey, could you help me out?

                Formal: \(text)
                Casual:
                """
                stopTokens = ["\n\n", "\nFormal:"]
            case .funny:
                prompt = """
                Translate sentences from normal English to Bender-speak (maintain the exact same question or statement):

                Normal: Should we order pizza tonight?
                Bender-speak: Should us meatbags order some greasy pizza tonight?

                Normal: I'm going to the store.
                Bender-speak: I'm heading to the store, baby!

                Normal: \(text)
                Bender-speak:
                """
                stopTokens = ["\n\n", "\nNormal:"]
            }

            // Create request body
            // Use higher temperature for creative styles
            let temperature: Double = (style == .funny || style == .casual) ? 0.3 : 0.1

            // Dynamic token limit based on input length
            // Estimate tokens: ~1.3 tokens per word in English
            let wordCount = text.split(separator: " ").count
            let estimatedInputTokens = Int(Double(wordCount) * 1.3)

            // Allow 2x expansion for rewriting, with min 64 and max 512
            let maxTokens = min(max(estimatedInputTokens * 2, 64), 512)

            print("📊 Input: \(wordCount) words, estimated \(estimatedInputTokens) tokens, allowing \(maxTokens) output tokens")

            let requestBody: [String: Any] = [
                "prompt": prompt,
                "n_predict": maxTokens,
                "temperature": temperature,
                "repeat_penalty": 1.1,  // Prevent repetitive loops
                "stop": stopTokens
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                completion(.failure(NSError(domain: "LlamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
                return
            }

            var request = URLRequest(url: self.serverURL)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "LlamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response data"])))
                    return
                }

                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let content = json["content"] as? String {
                        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

                        // If output is empty or suspiciously short (less than 3 chars), return original
                        if trimmed.isEmpty || trimmed.count < 3 {
                            print("⚠️ LLM output too short, using original text")
                            completion(.success(text))
                        } else {
                            print("✅ LLM correction successful: '\(trimmed)'")
                            completion(.success(trimmed))
                        }
                    } else {
                        print("⚠️ LLM response parsing failed, using original text")
                        completion(.success(text))
                    }
                } catch {
                    print("⚠️ LLM error: \(error), using original text")
                    completion(.success(text))
                }
            }

            task.resume()
        }
    }

    func unloadModel() {
        if let process = serverProcess, process.isRunning {
            process.terminate()
            print("🛑 LLM server stopped")
        }
        serverProcess = nil
        modelPath = nil
    }

    deinit {
        unloadModel()
    }
}
