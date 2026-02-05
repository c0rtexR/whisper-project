import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

struct HistoryView: View {
    @ObservedObject var history = TranscriptionHistory.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Transcription History")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    history.clearHistory()
                }
                .disabled(history.items.isEmpty)
                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // History list
            if history.items.isEmpty {
                VStack {
                    Spacer()
                    Text("No transcriptions yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(history.items) { item in
                            HistoryItemRow(item: item)
                            if item.id != history.items.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct HistoryItemRow: View {
    let item: TranscriptionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .onAppear {
                print("🎨 Rendering history item - whisperText: '\(item.whisperText)', llmText: '\(item.llmText ?? "nil")'")
            }

            if let llmText = item.llmText {
                // Show both versions for comparison
                VStack(alignment: .leading, spacing: 12) {
                    // Whisper version
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Whisper:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.whisperText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(4)
                    }

                    // LLM corrected version
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LLM Corrected:")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(llmText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: {
                        copyToClipboard(item.whisperText)
                    }) {
                        Label("Copy Whisper", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        copyToClipboard(llmText)
                    }) {
                        Label("Copy LLM", systemImage: "doc.on.doc.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Only Whisper version available
                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisper:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.whisperText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: {
                    copyToClipboard(item.whisperText)
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
