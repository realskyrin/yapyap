import SwiftUI
import AppKit
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

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keyMonitor: KeyMonitor!
    private var audioEngine: AudioEngine!
    private var asrClient: ASRClient!
    private var overlayWindow: OverlayWindow!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupComponents()
        setupBindings()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "yapyap")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        let instructions = NSMenuItem(title: "Hold fn to record", action: nil, keyEquivalent: "")
        instructions.isEnabled = false
        menu.addItem(instructions)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit yapyap", action: #selector(quitApp), keyEquivalent: "q"))
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

        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
            }
            self.overlayWindow.show()
        }

        asrClient.onTextUpdate = { text in
            let processed = TextProcessor.process(text)
            TextInjector.update(fullText: processed)
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
            self.overlayWindow.hide()
        }

        // Delay 0.5s before stopping audio to capture trailing speech
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.audioEngine.stop()
            self.asrClient.sendLastAudio()

            // Give the server time to process the final audio before disconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.asrClient.disconnect()
            }
        }
    }

    private func showNotConfiguredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "yapyap Not Configured"
            alert.informativeText = "Please set your App Key and Access Key in Settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
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
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "yapyap Settings"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
