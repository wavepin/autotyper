#if DEBUG
import AppKit
import ApplicationServices

@MainActor
enum DevelopmentChecks {
    static func run(to path: String, statusChecks: [String: Bool]) {
        let editor = ProbeEditor(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        editor.string = "Hello 👋 world"
        let window = NSWindow(contentRect: editor.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor
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
        var data: [String: Any] = [
            "selectAll": selected, "copyRouting": copied, "cutRouting": cut,
            "plainPasteRouting": pasted, "unrelatedShortcutPassesThrough": unrelatedPassesThrough,
            "accessibilityTrusted": AXIsProcessTrusted(), "bundlePath": Bundle.main.bundlePath
        ]
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
