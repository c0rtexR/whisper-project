import Cocoa
import SwiftUI
import AVFoundation
import Combine
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var appState = AppState()
    var whisperService = WhisperService()
    var llamaService = LlamaService()
    var audioRecorder = AudioRecorder()

    private var settingsWindow: NSWindow?
    private var firstLaunchWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var updateCancellable: AnyCancellable?
    private var recordingPanel: NSPanel?
    private var streamingTimer: Timer?
    private var streamingState = StreamingTranscriptionState()
    private var isStreamingInProgress = false
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
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        updateMenuBarIcon()

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

        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Watch for update downloads completing
        updateCancellable = UpdateChecker.shared.$downloadedUpdatePath
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                if path != nil {
                    self?.updateMenuBarIcon()
                    self?.sendUpdateNotification()
                }
            }

        // Listen for settings open request from other views
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: .openSettings, object: nil)

        // Check for updates if enabled
        if AppSettings.shared.autoCheckForUpdates {
            // Delay by 3 seconds to not slow down launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UpdateChecker.shared.checkForUpdates(silent: true)
            }
        }

        // Show toast if app was just updated
        if CommandLine.arguments.contains("--just-updated") {
            showUpdateToast()
        }
    }

    private func sendUpdateNotification() {
        guard let update = UpdateChecker.shared.availableUpdate,
              let version = update.version else { return }

        let content = UNMutableNotificationContent()
        content.title = "Update Ready"
        content.body = "Whisper Dictation v\(version.string) is ready to install."
        content.sound = .default
        content.categoryIdentifier = "UPDATE"

        let request = UNNotificationRequest(identifier: "update-ready", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == "UPDATE" {
            if let path = UpdateChecker.shared.downloadedUpdatePath {
                UpdateChecker.shared.installUpdate(zipPath: path)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    private func showUpdateToast() {
        let version = AppVersion.current.string

        let hostingView = NSHostingController(rootView:
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Whisper Dictation Updated")
                        .font(.headline)
                    Text("Now running v\(version)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .fixedSize()
        )

        let contentSize = hostingView.view.fittingSize

        let toast = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width + 40, height: contentSize.height + 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        toast.backgroundColor = NSColor.windowBackgroundColor
        toast.isOpaque = false
        toast.level = .floating
        toast.hasShadow = true
        toast.isMovable = false
        toast.contentViewController = hostingView

        // Position near top of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            toast.setFrameOrigin(NSPoint(
                x: screenFrame.midX - toast.frame.width / 2,
                y: screenFrame.maxY - 100
            ))
        }

        // Fade in
        toast.alphaValue = 0
        toast.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            toast.animator().alphaValue = 1
        }

        // Fade out after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                toast.animator().alphaValue = 0
            }, completionHandler: {
                toast.close()
            })
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
            showRecordingPanel()

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
        dismissRecordingPanel()

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

    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click: show menu
            let menu = createMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            // Clear menu after so left click isn't intercepted next time
            DispatchQueue.main.async {
                self.statusItem.menu = nil
            }
        } else {
            // Left click: open history
            openHistory()
        }
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Writing style submenu when LLM is enabled
        if AppSettings.shared.useLLMCorrection {
            let styleMenu = NSMenu()
            for style in WritingStyle.allCases {
                let item = NSMenuItem(title: style.rawValue, action: #selector(selectStyle(_:)), keyEquivalent: "")
                item.representedObject = style
                if style == AppSettings.shared.writingStyle {
                    item.state = .on
                }
                styleMenu.addItem(item)
            }
            styleMenu.addItem(NSMenuItem.separator())
            let cycleItem = NSMenuItem(title: "Cycle Style", action: #selector(cycleStyle), keyEquivalent: "s")
            cycleItem.keyEquivalentModifierMask = [.command, .shift]
            styleMenu.addItem(cycleItem)

            let styleItem = NSMenuItem(title: "Style: \(AppSettings.shared.writingStyle.rawValue)", action: nil, keyEquivalent: "")
            styleItem.submenu = styleMenu
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

        // Update & Restart (only show when update is downloaded)
        if let update = UpdateChecker.shared.availableUpdate,
           let version = update.version,
           UpdateChecker.shared.downloadedUpdatePath != nil {
            let updateItem = NSMenuItem(title: "Update & Restart (v\(version.string))", action: #selector(installUpdate), keyEquivalent: "")
            menu.addItem(updateItem)
        }

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
            window.setContentSize(NSSize(width: 500, height: 550))
            window.center()

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openModelManager() {
        openSettings()
    }

    @objc func selectStyle(_ sender: NSMenuItem) {
        if let style = sender.representedObject as? WritingStyle {
            AppSettings.shared.writingStyle = style
            updateMenuBarIcon()
        }
    }

    @objc func cycleStyle() {
        AppSettings.shared.writingStyle = AppSettings.shared.writingStyle.next()
        updateMenuBarIcon()
    }

    @objc func installUpdate() {
        if let path = UpdateChecker.shared.downloadedUpdatePath {
            UpdateChecker.shared.installUpdate(zipPath: path)
        }
    }

    @objc func quit() {
        // Stop hotkey monitoring
        HotkeyManager.shared.stopMonitoring()

        // Use exit() instead of terminate() to avoid Metal cleanup crash
        // This is a workaround for ggml_metal_rsets_free abort issue
        exit(0)
    }

    private func showRecordingPanel() {
        guard AppSettings.shared.showVisualFeedback else { return }

        let showStreaming = AppSettings.shared.enableStreamingPreview

        let panelView: AnyView
        if showStreaming {
            // Combined: audio level + streaming text
            panelView = AnyView(
                VStack(spacing: 4) {
                    AudioLevelView(recorder: audioRecorder)
                    StreamingTranscriptionView(state: streamingState)
                }
                .padding(6)
            )
        } else {
            // Audio level only
            panelView = AnyView(
                AudioLevelView(recorder: audioRecorder)
                    .padding(6)
            )
        }

        let hostingController = NSHostingController(rootView: panelView)
        let contentSize = hostingController.view.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width + 12, height: contentSize.height + 12),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.isOpaque = false
        panel.level = .floating
        panel.hasShadow = true
        panel.isMovable = false
        panel.contentViewController = hostingController

        // Position near the menu bar icon
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.frame
            panel.setFrameOrigin(NSPoint(
                x: buttonFrame.midX - panel.frame.width / 2,
                y: buttonFrame.minY - panel.frame.height - 4
            ))
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: screenFrame.midX - panel.frame.width / 2,
                y: screenFrame.maxY - 40
            ))
        }

        panel.orderFront(nil)
        recordingPanel = panel

        // Start streaming timer if enabled
        if showStreaming {
            streamingState.text = ""
            streamingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.performStreamingTranscription()
            }
        }
    }

    private func dismissRecordingPanel() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        isStreamingInProgress = false
        streamingState.text = ""

        recordingPanel?.close()
        recordingPanel = nil
    }

    private func performStreamingTranscription() {
        guard !isStreamingInProgress else { return }
        isStreamingInProgress = true

        let samples = audioRecorder.getCurrentAudioSamples()
        guard samples.count > 8000 else { // At least 0.5s of audio
            isStreamingInProgress = false
            return
        }

        whisperService.transcribeChunk(samples: samples) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if case .success(let text) = result, !text.isEmpty {
                    self.streamingState.text = text
                }
                self.isStreamingInProgress = false
            }
        }
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
