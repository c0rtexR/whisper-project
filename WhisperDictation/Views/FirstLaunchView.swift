import SwiftUI

struct FirstLaunchView: View {
    @StateObject private var downloader = ModelDownloader()
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedModel: WhisperModel = WhisperModel.availableModels.first(where: { $0.id == "large-v3" }) ?? WhisperModel.availableModels[0]
    @State private var isDownloading = false
    @State private var showError = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Welcome to Whisper Dictation")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("System-wide voice dictation powered by OpenAI's Whisper")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()
                    .padding(.vertical)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Choose a model to download:")
                        .font(.headline)

                    ForEach(WhisperModel.availableModels) { model in
                        ModelRow(
                            model: model,
                            isSelected: selectedModel.id == model.id,
                            isDownloaded: settings.isModelDownloaded(model.id)
                        )
                        .onTapGesture {
                            selectedModel = model
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(10)

                if downloader.isDownloading {
                    VStack(spacing: 10) {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Downloading \(downloader.currentModel ?? "")...")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(downloader.downloadProgress * 100))%")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }

                            ProgressView(value: downloader.downloadProgress)
                                .progressViewStyle(.linear)
                        }

                        Button("Cancel") {
                            downloader.cancelDownload()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    HStack {
                        if settings.isModelDownloaded(selectedModel.id) {
                            Button("Use This Model") {
                                settings.selectedModel = selectedModel.id
                                settings.hasCompletedSetup = true
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Download & Continue") {
                                downloadSelectedModel()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if let error = downloader.downloadError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(40)
        }
        .frame(width: 600, height: 700)
    }

    private func downloadSelectedModel() {
        downloader.downloadModel(selectedModel) { result in
            switch result {
            case .success:
                settings.selectedModel = selectedModel.id
                settings.hasCompletedSetup = true
                dismiss()
            case .failure(let error):
                print("Download failed: \(error)")
            }
        }
    }
}

struct ModelRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloaded: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(model.name)
                        .font(.headline)

                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text(model.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Size: \(model.size)")
                    Text("•")
                    Text("RAM: \(model.estimatedRAM)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}
