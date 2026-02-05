import Foundation
import Combine

class ModelDownloader: NSObject, ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadError: String?
    @Published var currentModel: String?

    private var downloadTask: URLSessionDownloadTask?
    private var destination: URL?
    private var completionHandler: ((Result<URL, Error>) -> Void)?

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

        self.destination = destination
        self.completionHandler = completion

        DispatchQueue.main.async {
            self.isDownloading = true
            self.downloadProgress = 0.0
            self.currentModel = name
            self.downloadError = nil
        }

        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        destination = nil
        completionHandler = nil
        DispatchQueue.main.async {
            self.isDownloading = false
            self.currentModel = nil
            self.downloadProgress = 0.0
        }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let destination = destination else { return }
        let completion = completionHandler

        DispatchQueue.main.async {
            self.isDownloading = false
            self.currentModel = nil
            self.destination = nil
            self.completionHandler = nil
        }

        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            completion?(.success(destination))
        } catch {
            DispatchQueue.main.async {
                self.downloadError = error.localizedDescription
            }
            completion?(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let completion = completionHandler

        DispatchQueue.main.async {
            self.isDownloading = false
            self.currentModel = nil
            self.downloadError = error.localizedDescription
            self.destination = nil
            self.completionHandler = nil
        }

        completion?(.failure(error))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgress = progress
        }
    }
}
