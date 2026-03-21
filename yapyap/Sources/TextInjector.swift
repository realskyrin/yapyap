import Cocoa
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "TextInjector")

enum TextInjector {
    private static var injectedText = ""
    private static let queue = DispatchQueue(label: "cn.skyrin.yapyap.textinjector")

    /// Check and request Accessibility permission.
    static func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        logger.info("Accessibility trusted: \(trusted)")
        return trusted
    }

    /// Reset state at the beginning of a recording session.
    static func reset() {
        queue.sync { injectedText = "" }
    }

    /// Delete all injected text and reset state.
    static func clear() {
        queue.sync {
            let count = injectedText.count
            if count > 0 {
                sendBackspaces(count: count)
            }
            injectedText = ""
        }
    }

    /// Update the text at cursor to match the new full text from ASR.
    /// Handles both appending new characters and correcting revised text.
    static func update(fullText: String) {
        queue.sync {
            let oldText = injectedText

            // Find common prefix
            let commonPrefix = String(zip(oldText, fullText).prefix(while: { $0 == $1 }).map(\.0))
            let charsToDelete = oldText.count - commonPrefix.count
            let newChars = String(fullText.dropFirst(commonPrefix.count))

            if charsToDelete == 0 && newChars.isEmpty { return }

            logger.info("Injecting: delete=\(charsToDelete), insert=\"\(newChars)\" (old=\"\(oldText)\" -> new=\"\(fullText)\")")

            // Delete divergent old characters
            if charsToDelete > 0 {
                sendBackspaces(count: charsToDelete)
            }

            // Type new characters
            if !newChars.isEmpty {
                sendText(newChars)
            }

            injectedText = fullText
        }
    }

    private static func sendBackspaces(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Delete), keyDown: true)
            keyDown?.flags = []  // Clear all modifiers (fn key held during recording)
            keyDown?.post(tap: .cghidEventTap)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Delete), keyDown: false)
            keyUp?.flags = []
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private static func sendText(_ text: String) {
        // Use CGEvent with unicode string for reliable CJK input
        let source = CGEventSource(stateID: .hidSystemState)
        let utf16 = Array(text.utf16)

        // CGEventKeyboardSetUnicodeString can handle up to 20 chars at a time
        let chunkSize = 20
        for i in stride(from: 0, to: utf16.count, by: chunkSize) {
            let end = min(i + chunkSize, utf16.count)
            var chunk = Array(utf16[i..<end])

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyDown?.flags = []  // Clear all modifiers (fn key held during recording)
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyUp?.flags = []
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
