#if DEBUG
import AppKit
import ApplicationServices
import AutotyperCore

@MainActor
enum DevelopmentChecks {
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
