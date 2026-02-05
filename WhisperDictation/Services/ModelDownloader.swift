import Foundation
import Combine

class ModelDownloader: NSObject, ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadError: String?
    @Published var currentModel: String?

    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func downloadLLMModel(_ model: LLMModel, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isDownloading else {
            completion(.failure(NSError(domain: "ModelDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download already in progress"])))
            return
        }

        let destinationURL = AppSettings.shared.modelsDirectory.appendingPathComponent(model.id)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            completion(.success(destinationURL))
            return
        }

        startDownload(name: model.name, urlString: model.downloadURL, destination: destinationURL, completion: completion)
    }

    func downloadModel(_ model: WhisperModel, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isDownloading else {
            completion(.failure(NSError(domain: "ModelDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download already in progress"])))
            return
        }

        let destinationURL = AppSettings.shared.modelPath(model.id)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            completion(.success(destinationURL))
            return
        }

        startDownload(name: model.name, urlString: model.downloadURL, destination: destinationURL, completion: completion)
    }

    private func startDownload(name: String, urlString: String, destination: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "ModelDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        DispatchQueue.main.async {
            self.isDownloading = true
            self.downloadProgress = 0.0
            self.currentModel = name
            self.downloadError = nil
        }

        downloadTask = urlSession.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isDownloading = false
                self.currentModel = nil
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.downloadError = error.localizedDescription
                }
                completion(.failure(error))
                return
            }

            guard let tempURL = tempURL else {
                let error = NSError(domain: "ModelDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No temporary file"])
                completion(.failure(error))
                return
            }

            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: tempURL, to: destination)
                completion(.success(destination))
            } catch {
                DispatchQueue.main.async {
                    self.downloadError = error.localizedDescription
                }
                completion(.failure(error))
            }
        }

        downloadTask?.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        DispatchQueue.main.async {
            self.isDownloading = false
            self.currentModel = nil
            self.downloadProgress = 0.0
        }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in completion block
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgress = progress
            print("Download progress: \(Int(progress * 100))% - \(totalBytesWritten) / \(totalBytesExpectedToWrite) bytes")
        }
    }
}
