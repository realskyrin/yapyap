import Cocoa

class KeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?
    private var flagsMonitor: Any?
    private var localMonitor: Any?
    private var isFnPressed = false

    func start() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let fnPressed = event.modifierFlags.contains(.function)

        if fnPressed && !isFnPressed {
            isFnPressed = true
            onFnDown?()
        } else if !fnPressed && isFnPressed {
            isFnPressed = false
            onFnUp?()
        }
    }

    func stop() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        stop()
    }
}
