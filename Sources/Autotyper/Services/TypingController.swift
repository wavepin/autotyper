import AppKit
import ApplicationServices
import Carbon
import Observation
import AutotyperCore

@MainActor @Observable
final class TypingController {
    enum Phase: Equatable { case idle, countdown(Int), typing(Int, Int) }
    var text = ""
    var delay = 5 { didSet { UserDefaults.standard.set(delay, forKey: "startDelay") } }
    var gentle = false { didSet { UserDefaults.standard.set(gentle, forKey: "gentlePace") } }
    private(set) var phase: Phase = .idle
    var message = "Choose a delay, then place your cursor in the destination."
    var trusted = AXIsProcessTrusted()
    var onChange: (() -> Void)?
    var onStart: (() -> Void)?
    private var operation: Task<Void, Never>?
    var busy: Bool { phase != .idle }

    init() {
        let saved = UserDefaults.standard.integer(forKey: "startDelay")
        delay = [3, 5, 10, 15, 30].contains(saved) ? saved : 5
        gentle = UserDefaults.standard.bool(forKey: "gentlePace")
    }

    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
    }
    func refreshPermission() { trusted = AXIsProcessTrusted() }
    func start(history: HistoryStore) {
        guard !busy, !text.isEmpty else { return }
        refreshPermission()
        guard trusted else { requestPermission(); message = "Enable Autotyper in System Settings → Privacy & Security → Accessibility, then try again."; return }
        let payload = TextPayload.events(text)
        guard !payload.isEmpty else { return }
        history.add(text)
        let seconds = delay
        let interval: UInt64 = gentle ? 20_000_000 : 4_000_000
        setPhase(.countdown(seconds))
        message = "Place your cursor now. Click the menu bar icon or press ⌃⌥⌘X to cancel."
        onStart?()
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                for remaining in stride(from: seconds, through: 1, by: -1) {
                    self.setPhase(.countdown(remaining))
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                try Task.checkCancellation()
                guard let target = NSWorkspace.shared.frontmostApplication,
                      target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                    self.finish("No destination selected. Click a text field in another app and try again."); return
                }
                let pid = target.processIdentifier
                let source = CGEventSource(stateID: .privateState)
                for (index, units) in payload.enumerated() {
                    try Task.checkCancellation()
                    guard AXIsProcessTrusted(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
                        self.finish("Stopped because the destination app or Accessibility permission changed."); return
                    }
                    guard !IsSecureEventInputEnabled(), !self.focusIsSecure(pid: pid) else {
                        self.finish("Stopped: macOS secure input or a password field is active."); return
                    }
                    // Do not let held shortcut modifiers change emitted text.
                    let flags = CGEventSource.flagsState(.combinedSessionState)
                    guard flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty else {
                        self.finish("Stopped because a modifier key was held. Release the keys and try again."); return
                    }
                    guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                          let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                        self.finish("macOS could not create keyboard events."); return
                    }
                    down.flags = []; up.flags = []
                    units.withUnsafeBufferPointer { buffer in
                        down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                        up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                    }
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                    if index % 20 == 0 { self.setPhase(.typing(index + 1, payload.count)) }
                    try await Task.sleep(nanoseconds: interval)
                }
                self.finish("Finished sending text to \(target.localizedName ?? "the destination").")
            } catch { /* cancellation is handled synchronously by abort() */ }
        }
    }
    func abort() {
        guard busy else { return }
        operation?.cancel(); operation = nil
        finish("Cancelled. Text already typed remains in the destination.")
    }
    private func finish(_ message: String) { self.message = message; setPhase(.idle) }
    private func setPhase(_ value: Phase) { phase = value; onChange?() }
    private func focusIsSecure(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.02)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        let element = unsafeDowncast(value, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(element, 0.02)
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        return (subrole as? String) == "AXSecureTextField"
    }
}
