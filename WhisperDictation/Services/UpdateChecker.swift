import Foundation
import Combine
import AppKit

class UpdateChecker: NSObject, ObservableObject {
    static let shared = UpdateChecker()

    @Published var isCheckingForUpdates = false
    @Published var availableUpdate: GitHubRelease?
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading = false
    @Published var error: String?
    @Published var downloadedUpdatePath: URL?

    private let githubAPIURL = "https://api.github.com/repos/c0rtexR/whisper-project/releases/latest"
    private var downloadTask: URLSessionDownloadTask?

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Check for Updates

    func checkForUpdates(silent: Bool = false) {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        error = nil

        guard let url = URL(string: githubAPIURL) else {
            isCheckingForUpdates = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isCheckingForUpdates = false

                if let error = error {
                    self.error = "Failed to check for updates: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self.error = "No data received from GitHub"
                    return
                }

                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

                    guard let remoteVersion = release.version else {
                        self.error = "Invalid version format in release"
                        return
                    }

                    let currentVersion = AppVersion.current

                    if remoteVersion > currentVersion {
                        self.availableUpdate = release
                        self.downloadUpdate(release: release)
                    } else {
                        if !silent {
                            // Show "You're up to date" dialog
                        }
                    }

                    // Update last check date
                    AppSettings.shared.lastUpdateCheckDate = Date().timeIntervalSince1970
                } catch {
                    self.error = "Failed to parse release info: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    // MARK: - Download Update

    func downloadUpdate(release: GitHubRelease) {
        guard let asset = release.zipAsset,
              let url = URL(string: asset.browserDownloadUrl) else {
            error = "No downloadable asset found"
            return
        }

        isDownloading = true
        downloadProgress = 0.0
        error = nil

        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
    }

    // MARK: - Verification

    private func verifyChecksum(fileURL: URL, expectedChecksum: String) -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        return hashString.lowercased() == expectedChecksum.lowercased()
    }

    // MARK: - Installation

    func installUpdate(zipPath: URL) {
        // Move downloaded zip to a safe location
        let tempDir = FileManager.default.temporaryDirectory
        let extractPath = tempDir.appendingPathComponent("WhisperDictationUpdate")

        do {
            // Clean up previous extract directory
            if FileManager.default.fileExists(atPath: extractPath.path) {
                try FileManager.default.removeItem(at: extractPath)
            }

            // Extract zip
            try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true)

            // Use unzip command
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", zipPath.path, "-d", extractPath.path]
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                error = "Failed to extract update"
                return
            }

            // Find .app in extracted directory
            let contents = try FileManager.default.contentsOfDirectory(at: extractPath, includingPropertiesForKeys: nil)
            guard let appBundle = contents.first(where: { $0.pathExtension == "app" }) else {
                error = "No app bundle found in update"
                return
            }

            // Create installation helper script
            let scriptPath = createInstallScript(newAppPath: appBundle.path)

            // Launch script and quit
            let scriptProcess = Process()
            scriptProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            scriptProcess.arguments = [scriptPath]
            try scriptProcess.run()

            // Quit current app (script will replace and restart)
            // Use exit(0) instead of NSApp.terminate to avoid Metal cleanup crash
            exit(0)

        } catch {
            self.error = "Installation failed: \(error.localizedDescription)"
        }
    }

    private func createInstallScript(newAppPath: String) -> String {
        let currentAppPath = Bundle.main.bundlePath
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("install_update.sh").path

        let script = """
        #!/bin/bash
        # Wait for app to quit
        sleep 2

        # Remove old app
        rm -rf "\(currentAppPath)"

        # Move new app
        cp -R "\(newAppPath)" "\(currentAppPath)"

        # Remove quarantine and provenance attributes
        xattr -cr "\(currentAppPath)" 2>/dev/null || true

        # Wait for filesystem to settle
        sleep 1

        # Launch new app with updated flag
        open "\(currentAppPath)" --args --just-updated

        # Clean up
        rm -f "$0"
        """

        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        // Make executable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", scriptPath]
        try? process.run()
        process.waitUntilExit()

        return scriptPath
    }
}

// MARK: - URLSessionDownloadDelegate

extension UpdateChecker: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let availableUpdate = availableUpdate else { return }

        // Move to permanent location
        let downloadDir = FileManager.default.temporaryDirectory.appendingPathComponent("WhisperDictationUpdates")
        try? FileManager.default.createDirectory(at: downloadDir, withIntermediateDirectories: true)

        let destinationURL = downloadDir.appendingPathComponent("WhisperDictation-\(availableUpdate.tagName).zip")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            // Verify checksum if available
            if let expectedChecksum = availableUpdate.sha256Checksum {
                if verifyChecksum(fileURL: destinationURL, expectedChecksum: expectedChecksum) {
                    print("✅ Checksum verified")
                } else {
                    DispatchQueue.main.async {
                        self.error = "Checksum verification failed. Update may be corrupted."
                        self.isDownloading = false
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                self.downloadedUpdatePath = destinationURL
                self.isDownloading = false
                print("✅ Update downloaded: \(destinationURL.path)")
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to save update: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }
}
