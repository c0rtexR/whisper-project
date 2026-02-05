import Cocoa
import SwiftUI
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var appState = AppState()
    var whisperService = WhisperService()
    var llamaService = LlamaService()
    var audioRecorder = AudioRecorder()

    private var settingsWindow: NSWindow?
    private var firstLaunchWindow: NSWindow?
    private var historyWindow: NSWindow?
    private let recordingQueue = DispatchQueue(label: "com.whisperdictation.recording")
    private var _isRecording = false
    private var isRecording: Bool {
        get { recordingQueue.sync { _isRecording } }
        set { recordingQueue.sync { _isRecording = newValue } }
    }
    private var audioURL: URL?
    private var listeningTimer: Timer?
    private var listeningDotCount = 0
    private var listeningTextLength = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Whisper Dictation")
        }

        updateMenuBarIcon()
        statusItem.menu = createMenu()

        // Request permissions
        requestPermissions()

        // Check if first launch
        if !AppSettings.shared.hasCompletedSetup {
            showFirstLaunch()
        } else {
            // Load model
            loadWhisperModel()

            // Start hotkey monitoring
            startHotkeyMonitoring()
        }
    }

    private func requestPermissions() {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.showPermissionAlert(type: "Microphone")
                }
            }
        }

        // Check accessibility permission - first check without prompting
        let accessEnabled = AXIsProcessTrusted()

        if !accessEnabled {
            // Only prompt if not already granted
            DispatchQueue.main.async {
                self.showPermissionAlert(type: "Accessibility")
            }
        }
    }

    private func showPermissionAlert(type: String) {
        let alert = NSAlert()
        alert.messageText = "\(type) Permission Required"
        alert.informativeText = "Whisper Dictation needs \(type) access to function properly. Please grant permission in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func loadWhisperModel() {
        let modelPath = AppSettings.shared.modelPath(AppSettings.shared.selectedModel)

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            showFirstLaunch()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.whisperService.loadModel(at: modelPath)
                print("Whisper model loaded successfully")

                // Load LLM model if correction is enabled
                if AppSettings.shared.useLLMCorrection {
                    let llmModelPath = AppSettings.shared.modelsDirectory.appendingPathComponent(AppSettings.shared.llmModel)
                    if FileManager.default.fileExists(atPath: llmModelPath.path) {
                        try self.llamaService.loadModel(at: llmModelPath)
                        print("LLM model loaded successfully")
                    } else {
                        print("LLM model not found, skipping LLM correction")
                    }
                }
            } catch {
                print("Failed to load model: \(error)")
                DispatchQueue.main.async {
                    self.appState.transcriptionState = .error("Failed to load model")
                }
            }
        }
    }

    private func startHotkeyMonitoring() {
        print("🎤 AppDelegate: Starting hotkey monitoring...")

        // Register history hotkey (Cmd+Shift+H)
        HotkeyManager.shared.registerHistoryHotkey { [weak self] in
            print("🔔 History hotkey triggered!")
            DispatchQueue.main.async {
                self?.openHistory()
            }
        }

        // Register style cycle hotkey (Cmd+Shift+S)
        HotkeyManager.shared.registerStyleCycleHotkey { [weak self] in
            print("🎨 Style cycle hotkey triggered!")
            DispatchQueue.main.async {
                self?.cycleWritingStyle()
            }
        }

        // Start monitoring recording hotkey
        HotkeyManager.shared.startMonitoring { [weak self] isKeyDown in
            guard let self = self else { return }

            print("🎤 AppDelegate: Hotkey callback triggered! isKeyDown: \(isKeyDown)")
            let mode = AppSettings.shared.recordingMode

            if mode == .toggle {
                // Toggle mode: each press toggles recording state
                if isKeyDown {
                    print("🎤 Toggle mode: Toggling recording")
                    self.toggleRecording()
                }
            } else {
                // Hold mode: press starts, release stops
                if isKeyDown {
                    print("🎤 Hold mode: Starting recording")
                    self.startRecording()
                } else {
                    print("🎤 Hold mode: Stopping recording")
                    self.stopRecording()
                }
            }
        }
        print("🎤 AppDelegate: Hotkey monitoring setup complete")
    }

    private func toggleRecording() {
        print("🔄 toggleRecording called, current state: \(isRecording)")
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        print("▶️ startRecording called")
        guard !isRecording else {
            print("⚠️ Already recording, ignoring")
            return
        }

        do {
            audioURL = try audioRecorder.startRecording()
            isRecording = true
            appState.transcriptionState = .recording

            updateMenuBarIcon()

            if AppSettings.shared.playAudioFeedback {
                print("🔔 Playing audio feedback beep")
                NSSound.beep()
            }

            print("✅ Recording started successfully")
        } catch {
            print("❌ Failed to start recording: \(error)")
            appState.transcriptionState = .error("Failed to start recording")
        }
    }

    private func stopRecording() {
        print("⏹️ stopRecording called")
        guard isRecording, let audioURL = audioRecorder.stopRecording() else {
            print("⚠️ Not recording or failed to stop, ignoring")
            return
        }

        isRecording = false
        appState.transcriptionState = .processing
        updateMenuBarIcon()

        if AppSettings.shared.playAudioFeedback {
            print("🔔 Playing audio feedback beep")
            NSSound.beep()
        }

        print("✅ Recording stopped, starting transcription")

        // Transcribe
        whisperService.transcribe(audioURL: audioURL) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let text):
                print("Transcription: \(text)")

                // Apply LLM correction if enabled
                if AppSettings.shared.useLLMCorrection && !text.isEmpty {
                    print("Applying LLM correction...")
                    let selectedStyle = AppSettings.shared.writingStyle
                    self.llamaService.correctText(text, style: selectedStyle) { [weak self] correctionResult in
                        guard let self = self else { return }

                        DispatchQueue.main.async {
                            switch correctionResult {
                            case .success(let correctedText):
                                print("Corrected: \(correctedText)")
                                print("📝 Saving to history - Whisper: '\(text)', LLM: '\(correctedText)'")
                                // Save to history with both versions
                                TranscriptionHistory.shared.addTranscription(whisperText: text, llmText: correctedText)
                                // Insert text
                                TextInjector.insertText(correctedText)

                            case .failure(let error):
                                print("LLM correction failed, using original: \(error)")
                                // Fallback to original text (no LLM version)
                                TranscriptionHistory.shared.addTranscription(whisperText: text, llmText: nil)
                                TextInjector.insertText(text)
                            }

                            self.appState.transcriptionState = .idle
                            try? FileManager.default.removeItem(at: audioURL)
                            self.updateMenuBarIcon()
                        }
                    }
                } else {
                    // No LLM correction, use text directly
                    DispatchQueue.main.async {
                        if !text.isEmpty {
                            // Save to history (no LLM version)
                            TranscriptionHistory.shared.addTranscription(whisperText: text, llmText: nil)
                            // Insert text
                            TextInjector.insertText(text)
                        }

                        self.appState.transcriptionState = .idle
                        try? FileManager.default.removeItem(at: audioURL)
                        self.updateMenuBarIcon()
                    }
                }

            case .failure(let error):
                print("Transcription failed: \(error)")
                DispatchQueue.main.async {
                    self.appState.transcriptionState = .error("Transcription failed")
                    try? FileManager.default.removeItem(at: audioURL)
                    self.updateMenuBarIcon()
                }
            }
        }
    }

    private func cycleWritingStyle() {
        guard AppSettings.shared.useLLMCorrection else {
            print("⚠️ LLM correction not enabled, ignoring style cycle")
            return
        }

        let oldStyle = AppSettings.shared.writingStyle
        let newStyle = oldStyle.next()
        AppSettings.shared.writingStyle = newStyle

        print("🎨 Cycled style: \(oldStyle.rawValue) → \(newStyle.rawValue)")

        // Update menu bar to reflect new style
        updateMenuBarIcon()

        // Optional: play feedback sound
        if AppSettings.shared.playAudioFeedback {
            NSSound.beep()
        }
    }

    private func updateMenuBarIcon() {
        let iconName: String
        switch appState.transcriptionState {
        case .idle:
            iconName = "waveform.circle"
        case .recording:
            iconName = "waveform.circle.fill"
        case .processing:
            iconName = "waveform"
        case .error:
            iconName = "exclamationmark.circle"
        }

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Whisper Dictation")

            // Add style badge when LLM is enabled
            if AppSettings.shared.useLLMCorrection {
                button.title = " \(AppSettings.shared.writingStyle.number)"
            } else {
                button.title = ""
            }
        }

        statusItem.menu = createMenu()
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Status
        let statusItem = NSMenuItem(title: appState.transcriptionState.displayText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Model info
        let modelItem = NSMenuItem(title: "Model: \(AppSettings.shared.selectedModel)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)

        // Add writing style info when LLM is enabled
        if AppSettings.shared.useLLMCorrection {
            let styleItem = NSMenuItem(title: "Style: \(AppSettings.shared.writingStyle.rawValue)", action: nil, keyEquivalent: "")
            styleItem.isEnabled = false
            menu.addItem(styleItem)
        }

        menu.addItem(NSMenuItem.separator())

        // History
        let historyItem = NSMenuItem(title: "History...", action: #selector(openHistory), keyEquivalent: "h")
        historyItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(historyItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    @objc func openHistory() {
        if historyWindow == nil {
            let historyView = HistoryView()
            let hostingController = NSHostingController(rootView: historyView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Transcription History"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 600, height: 500))
            window.center()

            historyWindow = window
        }

        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 500, height: 400))
            window.center()

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openModelManager() {
        openSettings()
    }

    @objc func quit() {
        // Stop hotkey monitoring
        HotkeyManager.shared.stopMonitoring()

        // Use exit() instead of terminate() to avoid Metal cleanup crash
        // This is a workaround for ggml_metal_rsets_free abort issue
        exit(0)
    }

    private func showFirstLaunch() {
        let firstLaunchView = FirstLaunchView()
        let hostingController = NSHostingController(rootView: firstLaunchView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 600, height: 700))
        window.center()

        firstLaunchWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
