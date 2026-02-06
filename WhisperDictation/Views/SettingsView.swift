import SwiftUI
import ServiceManagement
import Cocoa

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var downloader = ModelDownloader()
    @State private var isRecordingHotkey = false

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            WhisperModelSettingsView(downloader: downloader)
                .tabItem {
                    Label("Whisper Models", systemImage: "waveform")
                }

            LLMModelSettingsView(downloader: downloader)
                .tabItem {
                    Label("LLM Models", systemImage: "brain")
                }

            HotkeySettingsView(isRecording: $isRecordingHotkey)
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }

            UpdatesSettingsView()
                .tabItem {
                    Label("Updates", systemImage: "arrow.down.circle")
                }
        }
        .frame(width: 500, height: 550)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                sectionHeader("Recording", icon: "mic.fill")
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Launch at login", isOn: $settings.launchAtLogin)
                            .onChange(of: settings.launchAtLogin) { newValue in
                                setLaunchAtLogin(enabled: newValue)
                            }

                        Divider()

                        Picker("Recording mode", selection: $settings.recordingMode) {
                            ForEach(RecordingMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }

                        Text(settings.recordingMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                sectionHeader("Language", icon: "globe")
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Language", selection: $settings.selectedLanguage) {
                            Text(WhisperLanguage.autoDetect.name).tag(WhisperLanguage.autoDetect.code)
                            Divider()
                            ForEach(WhisperLanguage.common) { lang in
                                Text(lang.name).tag(lang.code)
                            }
                            Divider()
                            ForEach(WhisperLanguage.others) { lang in
                                Text(lang.name).tag(lang.code)
                            }
                        }

                        if settings.selectedLanguage != "en" && settings.selectedLanguage != "auto" && settings.selectedModel.hasSuffix(".en") {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("English-only models don't support other languages. Switch to a multilingual model.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                sectionHeader("Text Input", icon: "doc.on.clipboard")
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Fast paste mode (clipboard)", isOn: $settings.useFastPasteMode)
                        Text("Uses clipboard to paste text instantly (recommended)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                sectionHeader("Feedback", icon: "bell")
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show visual feedback when recording", isOn: $settings.showVisualFeedback)
                        Toggle("Play audio feedback (beep)", isOn: $settings.playAudioFeedback)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                sectionHeader("LLM Correction", icon: "brain")
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Use LLM to correct transcriptions", isOn: $settings.useLLMCorrection)

                        if settings.useLLMCorrection {
                            Divider()

                            Picker("Writing style", selection: $settings.writingStyle) {
                                ForEach(WritingStyle.allCases, id: \.self) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }

                            Text(settings.writingStyle.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if settings.writingStyle == .custom {
                                TextEditor(text: $settings.customWritingPrompt)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 100)
                                    .border(Color.secondary.opacity(0.3))
                                Text("Use {text} as placeholder for the transcribed text")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("Download and manage models in the LLM Models tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                sectionHeader("Experimental", icon: "flask")
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show live transcription preview", isOn: $settings.enableStreamingPreview)
                        Text("Shows partial transcription while recording. Uses more CPU/GPU.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, -4)
    }

    private func setLaunchAtLogin(enabled: Bool) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("Bundle identifier not found")
            return
        }

        if #available(macOS 13.0, *) {
            // Modern API for macOS 13+
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // Legacy API for macOS 12 and below
            let launcherAppId = "\(bundleIdentifier).Launcher"
            SMLoginItemSetEnabled(launcherAppId as CFString, enabled)
        }
    }
}

struct WhisperModelSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var downloader: ModelDownloader

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Active Model: \(settings.selectedModel)")
                .font(.headline)

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(WhisperModel.availableModels) { model in
                        ModelManagementRow(
                            model: model,
                            isActive: settings.selectedModel == model.id && settings.isModelDownloaded(model.id),
                            downloader: downloader
                        )
                    }
                }
            }

            if downloader.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloader.downloadProgress) {
                        Text("Downloading \(downloader.currentModel ?? "")...")
                    }
                    Button("Cancel") {
                        downloader.cancelDownload()
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}

struct LLMModelSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var downloader: ModelDownloader

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Status:")
                    .font(.headline)
                Text(settings.useLLMCorrection ? "Enabled" : "Disabled")
                    .font(.headline)
                    .foregroundColor(settings.useLLMCorrection ? .green : .secondary)
            }

            if settings.useLLMCorrection {
                Text("Active Model: \(settings.llmModel)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Enable LLM correction in General settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(LLMModel.availableModels) { model in
                        LLMModelRow(
                            model: model,
                            isActive: settings.llmModel == model.id && settings.isLLMModelDownloaded(model.id),
                            downloader: downloader
                        )
                    }
                }
            }

            if downloader.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloader.downloadProgress) {
                        Text("Downloading \(downloader.currentModel ?? "")...")
                    }
                    Button("Cancel") {
                        downloader.cancelDownload()
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}

struct ModelManagementRow: View {
    let model: WhisperModel
    let isActive: Bool
    @ObservedObject private var settings = AppSettings.shared
    private var isDownloaded: Bool { settings.isModelDownloaded(model.id) }
    @ObservedObject var downloader: ModelDownloader

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    if isActive {
                        Text("(Active)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                Text("\(model.size) • \(model.estimatedRAM) RAM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDownloaded {
                HStack {
                    if !isActive {
                        Button("Use") {
                            AppSettings.shared.selectedModel = model.id
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Delete") {
                        deleteModel(model)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Download") {
                    downloadModel(model)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func downloadModel(_ model: WhisperModel) {
        downloader.downloadModel(model) { result in
            if case .success = result {
                AppSettings.shared.selectedModel = model.id
            }
        }
    }

    private func deleteModel(_ model: WhisperModel) {
        let path = AppSettings.shared.modelPath(model.id)
        try? FileManager.default.removeItem(at: path)

        // If we deleted the active model, switch to the next downloaded one
        if AppSettings.shared.selectedModel == model.id {
            if let nextModel = WhisperModel.availableModels.first(where: { $0.id != model.id && AppSettings.shared.isModelDownloaded($0.id) }) {
                AppSettings.shared.selectedModel = nextModel.id
            }
        }
        AppSettings.shared.modelRefreshTrigger.toggle()
    }
}

struct HotkeySettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Binding var isRecording: Bool
    @State private var localEventMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Shortcut")
                .font(.headline)

            Text("Current hotkey: \(hotkeyDescription)")
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)

            Button(isRecording ? "Press a key..." : "Record New Hotkey") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .buttonStyle(.borderedProminent)

            Text("Default: CapsLock (key code 57)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("Note: Accessibility permissions are required for global hotkey monitoring.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .onDisappear {
            stopRecording()
        }
    }

    private var hotkeyDescription: String {
        if settings.hotkey == 57 {
            return "CapsLock"
        }
        return "Key Code: \(settings.hotkey)"
    }

    private func startRecording() {
        isRecording = true
        print("🎹 Started recording hotkey...")

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let keyCode = event.keyCode
            print("🎹 Captured key: \(keyCode)")

            settings.hotkey = Int(keyCode)
            stopRecording()

            return nil // Consume the event
        }
    }

    private func stopRecording() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        isRecording = false
        print("🎹 Stopped recording hotkey")
    }
}

struct LLMModelRow: View {
    let model: LLMModel
    let isActive: Bool
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var downloader: ModelDownloader
    private var isDownloaded: Bool { settings.isLLMModelDownloaded(model.id) }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    if isActive {
                        Text("(Active)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                Text(model.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDownloaded {
                HStack {
                    if !isActive {
                        Button("Use") {
                            AppSettings.shared.llmModel = model.id
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Delete") {
                        deleteModel(model)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Download") {
                    downloadModel(model)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func downloadModel(_ model: LLMModel) {
        downloader.downloadLLMModel(model) { result in
            if case .success = result {
                AppSettings.shared.llmModel = model.id
            }
        }
    }

    private func deleteModel(_ model: LLMModel) {
        let path = AppSettings.shared.llmModelPath(model.id)
        try? FileManager.default.removeItem(at: path)
        AppSettings.shared.modelRefreshTrigger.toggle()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Whisper Dictation")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(AppVersion.current.string)")
                .foregroundColor(.secondary)

            Text("System-wide voice dictation powered by OpenAI's Whisper")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()

            Link("GitHub Repository", destination: URL(string: "https://github.com/c0rtexR/whisper-project")!)

            Text("Built with Swift and whisper.cpp")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct UpdatesSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var showUpdatePrompt = false

    var body: some View {
        Form {
            Section(header: Text("Automatic Updates")) {
                Toggle("Automatically check for updates", isOn: $settings.autoCheckForUpdates)

                if settings.lastUpdateCheckDate > 0 {
                    let date = Date(timeIntervalSince1970: settings.lastUpdateCheckDate)
                    Text("Last checked: \(date, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Current Version")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppVersion.current.string)
                        .foregroundColor(.secondary)
                }

                if let update = updateChecker.availableUpdate,
                   let newVersion = update.version {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text("Update available: \(newVersion.string)")
                            .foregroundColor(.blue)
                    }
                }
            }

            Section {
                Button(action: {
                    updateChecker.availableUpdate = nil
                    updateChecker.checkForUpdates(silent: false)
                }) {
                    HStack {
                        if updateChecker.isCheckingForUpdates {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(updateChecker.isCheckingForUpdates ? "Checking..." : "Check for Updates")
                    }
                }
                .disabled(updateChecker.isCheckingForUpdates)
            }

            if let error = updateChecker.error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showUpdatePrompt) {
            if let update = updateChecker.availableUpdate {
                UpdatePromptView(release: update, updateChecker: updateChecker)
            }
        }
        .onChange(of: updateChecker.availableUpdate) { newValue in
            if newValue != nil {
                showUpdatePrompt = true
            }
        }
        .onAppear {
            if updateChecker.availableUpdate != nil {
                showUpdatePrompt = true
            }
        }
    }
}

