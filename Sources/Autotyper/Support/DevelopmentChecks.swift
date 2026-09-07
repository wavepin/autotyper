#if DEBUG
import AppKit
import ApplicationServices
import Carbon
import AutotyperCore

@MainActor
enum DevelopmentChecks {
    static func runShortcutChecks(to path: String) {
        let data = shortcutChecks()
        try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
    }

    private static func shortcutChecks() -> [String: Bool] {
        let suite = "local.autotyper.shortcut-checks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let candidate = AppShortcut(keyCode: UInt32(kVK_F12), modifiers: UInt32(controlKey | optionKey | cmdKey | shiftKey), keyLabel: "F12")
        defaults.set(try! JSONEncoder().encode(candidate), forKey: "appShortcut")
        let first = GlobalShortcuts(defaults: defaults)
        first.register()
        defer { first.stop() }
        let second = GlobalShortcuts(defaults: defaults)
        second.register()
        defer { second.stop() }
        let conflict = !second.available && first.available
        let replacement = AppShortcut(keyCode: UInt32(kVK_F11), modifiers: candidate.modifiers, keyLabel: "F11")
        let rebound = first.rebind(replacement)
        let persisted = GlobalShortcuts(defaults: defaults).shortcut == replacement
        let secondRegistered = second.rebind(candidate)
        let conflictPreserves = secondRegistered && !first.rebind(candidate) && first.shortcut == replacement && first.available
        let invalid = !first.rebind(AppShortcut(keyCode: 0, modifiers: 0, keyLabel: "A")) && first.shortcut == replacement
        first.clear()
        let cleared = first.shortcut == nil && !first.available
        let reloaded = GlobalShortcuts(defaults: defaults)
        reloaded.register()
        let staysDisabled = reloaded.shortcut == nil && !reloaded.available
        reloaded.stop()
        let released = second.rebind(replacement)
        let canReenable = first.rebind(candidate)
        first.stop()
        let restored = first.shortcut == candidate
        return ["shortcutClear": cleared, "shortcutDisabledPersists": staysDisabled, "shortcutClearReleasesKey": released, "shortcutReenable": canReenable, "shortcutRegistration": rebound, "shortcutConflict": conflict,
                "shortcutPersistence": persisted, "shortcutConflictPreservesBinding": conflictPreserves,
                "shortcutRejectsUnmodifiedKey": invalid, "shortcutStopPreservesPreference": restored]
    }

    static func run(to path: String, statusChecks: [String: Bool]) {
        let editor = ProbeEditor(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        editor.string = "Hello 👋 world"
        let window = NSWindow(contentRect: editor.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(editor)
        func press(_ key: String, shift: Bool = false) -> Bool {
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: shift ? [.command, .shift] : [.command], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0)!
            return window.performKeyEquivalent(with: event)
        }
        let selected = press("a") && editor.selectedRange() == NSRange(location: 0, length: editor.string.utf16.count)
        let copied = press("c") && editor.lastAction == "copy"
        let cut = press("x") && editor.lastAction == "cut"
        let pasted = press("v") && editor.lastAction == "paste"
        let unrelatedPassesThrough = !press("j")
        var multilineActual: [String: String] = [:]
        var multilineChecks: [String: Bool] = [:]
        for mode in LineBreakMode.allCases {
            editor.string = ""
            editor.setSelectedRange(NSRange(location: 0, length: 0))
            let expected = "Test\nwith\n\nlinebreak\n"
            for units in TextPayload.events(expected) {
                let pair = KeyboardEvents.pair(units: units, lineBreakMode: mode, source: nil)!
                editor.keyDown(with: NSEvent(cgEvent: pair.down)!)
                editor.keyUp(with: NSEvent(cgEvent: pair.up)!)
            }
            multilineActual[mode.rawValue] = editor.string
            multilineChecks["multiline_" + mode.rawValue] = editor.string.replacingOccurrences(of: "\u{2028}", with: "\n") == expected
        }
        window.orderOut(nil)
        var data: [String: Any] = [
            "selectAll": selected, "copyRouting": copied, "cutRouting": cut,
            "plainPasteRouting": pasted, "unrelatedShortcutPassesThrough": unrelatedPassesThrough,
            "accessibilityTrusted": AXIsProcessTrusted(), "bundlePath": Bundle.main.bundlePath
        ]
        for (key, value) in shortcutChecks() { data[key] = value }
        data["multilineActual"] = multilineActual
        for (key, value) in multilineChecks { data[key] = value }
        for (key, value) in statusChecks { data[key] = value }
        try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
    }
}

private final class ProbeEditor: ShortcutTextView {
    var lastAction = ""
    override func copy(_ sender: Any?) { lastAction = "copy" }
    override func cut(_ sender: Any?) { lastAction = "cut" }
    override func pasteAsPlainText(_ sender: Any?) { lastAction = "paste" }
}
#endif
