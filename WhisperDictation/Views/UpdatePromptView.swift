import SwiftUI

struct UpdatePromptView: View {
    let release: GitHubRelease
    @ObservedObject var updateChecker: UpdateChecker
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            if let downloadedPath = updateChecker.downloadedUpdatePath {
                // Download complete - ready to install
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Update Ready to Install")
                    .font(.title)
                    .fontWeight(.bold)

                Text("The app will restart to complete installation")
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button("Install Later") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Restart & Install") {
                        updateChecker.installUpdate(zipPath: downloadedPath)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if updateChecker.isDownloading {
                // Downloading
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Downloading Update...")
                    .font(.title2)
                    .fontWeight(.semibold)

                ProgressView(value: updateChecker.downloadProgress) {
                    Text("\(Int(updateChecker.downloadProgress * 100))%")
                }
                .progressViewStyle(.linear)

                Button("Cancel") {
                    updateChecker.cancelDownload()
                    dismiss()
                }
                .buttonStyle(.bordered)
            } else {
                // Initial prompt
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Update Available")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(release.version?.string ?? "Unknown")")
                    .font(.headline)

                Text("Current: \(AppVersion.current.string)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                ScrollView {
                    Text(release.body)
                        .font(.body)
                        .padding()
                }
                .frame(maxHeight: 200)

                if let error = updateChecker.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                HStack(spacing: 12) {
                    Button("Later") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Download & Install") {
                        updateChecker.downloadUpdate(release: release)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}
