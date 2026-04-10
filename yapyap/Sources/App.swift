import SwiftUI
import AppKit
import AVFoundation
import Combine
import os.log

private let appLogger = Logger(subsystem: "cn.skyrin.yapyap", category: "App")

@main
struct YapYapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var keyMonitor: KeyMonitor!
    private var audioEngine: AudioEngine!
    private var asrClient: ASRClient!
    private var localASREngine: LocalASREngine!
    private var modelManager: ModelManager!
    private var overlayWindow: OverlayWindow!
    private var settingsWindow: NSWindow?
    private var startupWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var showMenuBarCancellable: AnyCancellable?
    private var languageCancellable: AnyCancellable?
    private var latestRawText = ""
    private var latestProcessedText = ""

    // Recording state machine: supports hold-to-record and click-to-toggle
    private enum RecordingMode {
        case idle
        case recording       // fn held down, recording in progress
        case clickRecording  // single-tap toggled, recording continues after fn release
        case processing      // post-recording text processing
    }
    private var recordingMode: RecordingMode = .idle
    private var fnPressTime: Date = .distantPast
    private let holdThreshold: TimeInterval = 0.3

    func applicationDidFinishLaunching(_ notification: Notification) {
        showStartupDialog()
    }

    private var startupLaunched = false

    private func showStartupDialog() {
        let dialog = SettingsView(isStartup: true) { [weak self] in
            guard let self else { return }
            self.startupLaunched = true
            self.startupWindow?.close()
            self.startupWindow = nil
            self.setupStatusItem()
            self.setupComponents()
            self.setupBindings()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 556),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: dialog)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        startupWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = SettingsStore.shared.showMenuBar
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "yapyap")
        }

        buildMenu()

        // Observe showMenuBar changes to toggle visibility immediately
        showMenuBarCancellable = SettingsStore.shared.$showMenuBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                self?.statusItem.isVisible = visible
            }

        // Rebuild menu when language changes
        languageCancellable = SettingsStore.shared.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.buildMenu()
            }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.menuSettings, action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        let instructions = NSMenuItem(title: L10n.menuHoldFn, action: nil, keyEquivalent: "")
        instructions.isEnabled = false
        menu.addItem(instructions)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.menuQuit, action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupComponents() {
        overlayWindow = OverlayWindow()
        overlayWindow.onCancel = { [weak self] in self?.handleEscCancel() }
        overlayWindow.onConfirm = { [weak self] in
            guard let self, self.recordingMode == .clickRecording else { return }
            self.recordingMode = .processing
            self.stopRecording()
        }
        audioEngine = AudioEngine()
        asrClient = ASRClient()
        localASREngine = LocalASREngine()
        modelManager = ModelManager.shared
        keyMonitor = KeyMonitor()
    }

    private func setupBindings() {
        keyMonitor.onFnDown = { [weak self] in
            self?.handleFnDown()
        }
        keyMonitor.onFnUp = { [weak self] in
            self?.handleFnUp()
        }
        keyMonitor.onEscPressed = { [weak self] in
            self?.handleEscCancel()
        }
        keyMonitor.start()

        SettingsStore.shared.$selectedModelId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] modelId in
                guard let self, !modelId.isEmpty else { return }
                // Only eagerly load the recognizer when we're actually in local ASR
                // mode. Loading it while the user is on online ASR would waste
                // hundreds of MB of ONNX memory for a model that never runs.
                guard SettingsStore.shared.asrMode == .local else { return }
                if let model = self.modelManager.model(for: modelId),
                   let path = self.modelManager.modelPath(for: model) {
                    self.localASREngine.loadModel(model, path: path)
                }
            }
            .store(in: &cancellables)

        // Release the ONNX recognizer whenever the user switches to online ASR.
        // Without this, picking a local model once keeps the model resident for
        // the lifetime of the process even after switching back to cloud ASR.
        SettingsStore.shared.$asrMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                guard let self else { return }
                appLogger.info("asrMode changed to \(mode.rawValue, privacy: .public)")
                if mode == .online {
                    self.localASREngine.unloadModel()
                }
            }
            .store(in: &cancellables)

        // The local Qwen3 should be resident iff the user actually intends to
        // use it: AI post-processing is enabled AND the mode is set to local.
        // If either of those turns false (user toggles off the AI master
        // switch OR switches back to an online provider), we release the
        // ~2.1 GB of MLX weights. Combining both publishers with CombineLatest
        // gives us a single source of truth for the "should local LLM be
        // loaded?" question.
        Publishers.CombineLatest(
            SettingsStore.shared.$aiEnabled,
            SettingsStore.shared.$useLocalAI
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { aiEnabled, useLocalAI in
            let shouldBeLoaded = aiEnabled && useLocalAI
            appLogger.info("AI state changed: aiEnabled=\(aiEnabled, privacy: .public) useLocalAI=\(useLocalAI, privacy: .public) shouldBeLoaded=\(shouldBeLoaded, privacy: .public)")
            if shouldBeLoaded {
                LLMModelManager.shared.ensureLoaded()
            } else {
                LLMModelManager.shared.unload()
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Fn key state machine

    private func handleFnDown() {
        switch recordingMode {
        case .idle:
            fnPressTime = Date()
            recordingMode = .recording
            startRecording()
        case .clickRecording, .recording, .processing:
            break
        }
    }

    private func handleFnUp() {
        switch recordingMode {
        case .recording:
            if Date().timeIntervalSince(fnPressTime) >= holdThreshold {
                // Long press release → stop immediately
                recordingMode = .processing
                stopRecording()
            } else {
                // Quick tap → enter click-toggle mode, keep recording
                recordingMode = .clickRecording
                DispatchQueue.main.async {
                    self.overlayWindow.enterClickMode()
                }
            }
        case .clickRecording:
            // Second tap → stop recording
            recordingMode = .processing
            stopRecording()
        case .idle, .processing:
            break
        }
    }

    private func handleEscCancel() {
        switch recordingMode {
        case .recording, .clickRecording:
            recordingMode = .idle
            cancelRecording()
        case .idle, .processing:
            break
        }
    }

    private func cancelRecording() {
        audioEngine.stop()
        if SettingsStore.shared.asrMode == .online {
            asrClient.disconnect()
        } else {
            localASREngine.stop()
        }
        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "yapyap")
            }
            self.overlayWindow.hide()
        }
    }

    private func startRecording() {
        let settings = SettingsStore.shared

        if settings.asrMode == .online {
            guard !settings.appKey.isEmpty, !settings.accessKey.isEmpty else {
                recordingMode = .idle
                showNotConfiguredAlert()
                return
            }
        } else {
            guard let model = modelManager.model(for: settings.selectedModelId),
                  let modelPath = modelManager.modelPath(for: model) else {
                recordingMode = .idle
                showNotConfiguredLocalAlert()
                return
            }
            // Load model if not already loaded
            if !localASREngine.isModelLoaded {
                localASREngine.loadModel(model, path: modelPath)
            }
            guard localASREngine.isModelLoaded else {
                showNotConfiguredLocalAlert()
                return
            }
        }

        if !TextInjector.checkAccessibility() {
            return
        }

        TextInjector.reset()
        latestRawText = ""
        latestProcessedText = ""

        SoundFeedback.shared.playStart()

        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
            }
            self.overlayWindow.show()
        }

        let textHandler: (String) -> Void = { [weak self] text in
            self?.latestRawText = text
            let processed = TextProcessor.process(text)
            self?.latestProcessedText = processed
            self?.overlayWindow.updateText(processed)
        }

        if settings.asrMode == .online {
            asrClient.onTextUpdate = textHandler
            asrClient.connect()

            audioEngine.onAudioBuffer = { [weak self] data in
                self?.asrClient.sendAudio(data: data)
            }
        } else {
            localASREngine.onTextUpdate = textHandler
            localASREngine.start()

            audioEngine.onAudioBuffer = { [weak self] data in
                self?.localASREngine.feedAudio(data)
            }
        }

        audioEngine.onAudioLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.overlayWindow.updateLevel(level)
            }
        }
        audioEngine.start()
    }

    private func stopRecording() {
        SoundFeedback.shared.playStop()

        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "yapyap")
            }
        }

        let settings = SettingsStore.shared

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.audioEngine.stop()

            if settings.asrMode == .online {
                self.asrClient.sendLastAudio()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self else { return }
                    self.asrClient.disconnect()
                    self.finalizeText()
                }
            } else {
                self.localASREngine.stop { [weak self] in
                    self?.finalizeText()
                }
            }
        }
    }

    private func finalizeText() {
        let settings = SettingsStore.shared
        let useAI = settings.aiEnabled && (settings.useLocalAI || !settings.aiApiKey.isEmpty)

        let textToInject = useAI ? self.latestRawText : self.latestProcessedText
        guard !textToInject.isEmpty else {
            self.overlayWindow.hide()
            self.recordingMode = .idle
            return
        }

        if useAI {
            self.overlayWindow.showProcessing()
            AIProcessor.process(text: textToInject) { [weak self] corrected in
                guard let self else { return }
                let finalText = TextProcessor.process(corrected)
                self.overlayWindow.updateText(finalText)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    TextInjector.update(fullText: finalText)
                    self.overlayWindow.hide()
                    self.recordingMode = .idle
                }
            }
        } else {
            TextInjector.update(fullText: textToInject)
            self.overlayWindow.hide()
            self.recordingMode = .idle
        }
    }

    private func showNotConfiguredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L10n.notConfiguredTitle
            alert.informativeText = L10n.notConfiguredMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.openSettings)
            alert.addButton(withTitle: L10n.cancel)
            if alert.runModal() == .alertFirstButtonReturn {
                self.openSettings()
            }
        }
    }

    private func showNotConfiguredLocalAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L10n.notConfiguredLocalTitle
            alert.informativeText = L10n.notConfiguredLocalMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.openSettings)
            alert.addButton(withTitle: L10n.cancel)
            if alert.runModal() == .alertFirstButtonReturn {
                self.openSettings()
            }
        }
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 556),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === startupWindow,
              !startupLaunched else { return }
        let micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let axGranted = AXIsProcessTrusted()
        if !micGranted || !axGranted {
            NSApp.terminate(nil)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
