import SwiftUI
import AppKit
import AVFoundation
import Combine

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
    private var overlayWindow: OverlayWindow!
    private var settingsWindow: NSWindow?
    private var startupWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var showMenuBarCancellable: AnyCancellable?
    private var languageCancellable: AnyCancellable?
    private var latestProcessedText = ""

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
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
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
        audioEngine = AudioEngine()
        asrClient = ASRClient()
        keyMonitor = KeyMonitor()
    }

    private func setupBindings() {
        keyMonitor.onRecordingStateChanged = { [weak self] isRecording in
            guard let self else { return }
            if isRecording {
                self.startRecording()
            } else {
                self.stopRecording()
            }
        }
        keyMonitor.start()
    }

    private func startRecording() {
        let settings = SettingsStore.shared
        guard !settings.appKey.isEmpty, !settings.accessKey.isEmpty else {
            showNotConfiguredAlert()
            return
        }

        if !TextInjector.checkAccessibility() {
            return
        }

        TextInjector.reset()
        latestProcessedText = ""

        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
            }
            self.overlayWindow.show()
        }

        asrClient.onTextUpdate = { [weak self] text in
            let processed = TextProcessor.process(text)
            self?.latestProcessedText = processed
            self?.overlayWindow.updateText(processed)
        }

        asrClient.connect()

        audioEngine.onAudioBuffer = { [weak self] data in
            self?.asrClient.sendAudio(data: data)
        }
        audioEngine.onAudioLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.overlayWindow.updateLevel(level)
            }
        }
        audioEngine.start()
    }

    private func stopRecording() {
        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "yapyap")
            }
        }

        // Delay 0.5s before stopping audio to capture trailing speech
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.audioEngine.stop()
            self.asrClient.sendLastAudio()

            // Give the server time to process the final audio before disconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.asrClient.disconnect()

                let textToInject = self.latestProcessedText
                guard !textToInject.isEmpty else {
                    self.overlayWindow.hide()
                    return
                }

                // AI post-processing
                let settings = SettingsStore.shared
                if settings.aiEnabled && !settings.aiApiKey.isEmpty {
                    self.overlayWindow.showProcessing()
                    AIProcessor.process(text: textToInject) { [weak self] corrected in
                        guard let self else { return }
                        // Show corrected text in bubble before injecting
                        self.overlayWindow.updateText(corrected)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            TextInjector.update(fullText: corrected)
                            self.overlayWindow.hide()
                        }
                    }
                } else {
                    TextInjector.update(fullText: textToInject)
                    self.overlayWindow.hide()
                }
            }
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

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
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
