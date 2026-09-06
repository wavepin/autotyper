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
    var allowSecureFields = false { didSet { UserDefaults.standard.set(allowSecureFields, forKey: "allowSecureFields") } }
    var lineBreakMode: LineBreakMode = .shiftReturn { didSet { UserDefaults.standard.set(lineBreakMode.rawValue, forKey: "lineBreakMode") } }
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
        lineBreakMode = LineBreakMode(rawValue: UserDefaults.standard.string(forKey: "lineBreakMode") ?? "") ?? .shiftReturn
        gentle = UserDefaults.standard.bool(forKey: "gentlePace")
        allowSecureFields = UserDefaults.standard.bool(forKey: "allowSecureFields")
    }

    func requestPermission() {
        refreshPermission()
        if !trusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    func refreshPermission() { trusted = AXIsProcessTrusted() }
    func start(history: HistoryStore) {
        guard !busy, !text.isEmpty else { return }
        refreshPermission()
        guard trusted else { message = "Accessibility is not active for this build. Open Settings; if Autotyper is already enabled, remove its old entry and add this app again, then reopen Autotyper."; return }
        let payload = TextPayload.events(text)
        guard !payload.isEmpty else { return }
        let secureAllowed = allowSecureFields
        if !secureAllowed { history.add(text) }
        let newlineMode = lineBreakMode
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
                self.setPhase(.typing(0, payload.count))
                var lastPercent = -1
                let source = CGEventSource(stateID: .privateState)
                for (index, units) in payload.enumerated() {
                    try Task.checkCancellation()
                    guard AXIsProcessTrusted(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
                        self.finish("Stopped because the destination app or Accessibility permission changed."); return
                    }
                    guard secureAllowed || (!IsSecureEventInputEnabled() && !self.focusIsSecure(pid: pid)) else {
                        self.finish("Stopped: macOS secure input or a password field is active."); return
                    }
                    // Do not let held shortcut modifiers change emitted text.
                    let flags = CGEventSource.flagsState(.combinedSessionState)
                    guard flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty else {
                        self.finish("Stopped because a modifier key was held. Release the keys and try again."); return
                    }
                    guard let events = KeyboardEvents.pair(units: units, lineBreakMode: newlineMode, source: source) else {
                        self.finish("macOS could not create keyboard events."); return
                    }
                    events.down.post(tap: .cghidEventTap)
                    events.up.post(tap: .cghidEventTap)
                    let percent = (index + 1) * 100 / payload.count
                    if percent != lastPercent {
                        self.setPhase(.typing(index + 1, payload.count))
                        lastPercent = percent
                    }
                    try await Task.sleep(nanoseconds: units == [10] ? max(interval, 20_000_000) : interval)
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
    #if DEBUG
    func previewPhase(_ phase: Phase) { setPhase(phase) }
    #endif
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
