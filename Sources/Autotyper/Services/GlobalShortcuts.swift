import AppKit
import Carbon
import Observation

struct AppShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String

    static let standard = AppShortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "T")
    var title: String {
        var label = ""
        if modifiers & UInt32(controlKey) != 0 { label += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { label += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { label += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { label += "⌘" }
        return label + keyLabel
    }
    var isValid: Bool {
        let required = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
        let allowed = required | UInt32(shiftKey)
        guard keyCode < 128, !keyLabel.isEmpty else { return false }
        guard modifiers & required != 0 else { return false }
        return modifiers & ~allowed == 0
    }
    static func capture(_ event: NSEvent) -> AppShortcut? {
        let flags = event.modifierFlags
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        let special: [UInt16: String] = [36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        let shortcut = AppShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers,
                                   keyLabel: special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "")
        return shortcut.isValid ? shortcut : nil
    }
}

@MainActor
@Observable
final class GlobalShortcuts {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let defaults: UserDefaults
    private(set) var shortcut: AppShortcut?
    private(set) var available = false
    var action: (() -> Void)?
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcut = .standard
        if let data = defaults.data(forKey: "appShortcut") {
            do {
                let saved = try JSONDecoder().decode(AppShortcut?.self, from: data)
                if let saved {
                    if saved.isValid { shortcut = saved }
                } else { shortcut = nil }
            } catch { /* Invalid preferences fall back to the default. */ }
        }
    }

    func register() {
        guard handler == nil else { return }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == 0x41545950, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { owner.action?() }
            return noErr
        }, 1, &event, context, &handler)
        guard result == noErr else { return }
        if let shortcut { available = install(shortcut) }
    }

    // Register the replacement first so a conflict never removes the working shortcut.
    func rebind(_ replacement: AppShortcut) -> Bool {
        guard replacement.isValid, handler != nil else { return false }
        if replacement == shortcut && available { return true }
        guard install(replacement) else { return false }
        shortcut = replacement
        available = true
        defaults.set(try? JSONEncoder().encode(replacement), forKey: "appShortcut")
        onChange?()
        return true
    }

    func clear() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        shortcut = nil
        available = false
        defaults.set(try? JSONEncoder().encode(Optional<AppShortcut>.none), forKey: "appShortcut")
        onChange?()
    }

    private func install(_ shortcut: AppShortcut) -> Bool {
        var newReference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: 0x41545950, id: 1), GetApplicationEventTarget(), 0, &newReference)
        guard status == noErr, let newReference else { return false }
        if let reference { UnregisterEventHotKey(reference) }
        reference = newReference
        return true
    }

    func stop() {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
        reference = nil
        handler = nil
        available = false
    }
}
