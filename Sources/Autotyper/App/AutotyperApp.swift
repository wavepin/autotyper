import AppKit
import SwiftUI

@main
struct AutotyperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let controller = TypingController()
    private let history = HistoryStore()
    private let shortcuts = GlobalShortcuts()
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var maintenance: Timer?
    private var permissionPoll: Timer?
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installEditingMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 430, height: 450)
        popover.contentViewController = NSHostingController(rootView: ContentView(controller: controller, history: history, shortcuts: shortcuts))
        controller.onChange = { [weak self] in self?.updateStatus() }
        controller.onStart = { [weak self] in
            guard let self else { return }
            self.popover.performClose(nil)
            self.previousApp?.activate(options: [])
        }
        shortcuts.action = { [weak self] in
            guard let self, self.popover.contentViewController?.view.window?.attachedSheet == nil else { return }
            if self.controller.busy { self.controller.abort(); self.show() }
            else { self.toggle() }
        }
        let shortcutUnavailable = "App shortcut unavailable. Choose another in the gear menu. You can still use the menu bar."
        shortcuts.onChange = { [weak self] in
            guard let self else { return }
            if self.controller.message == shortcutUnavailable { self.controller.message = "" }
            self.updateStatus()
        }
        shortcuts.register()
        if shortcuts.shortcut != nil && !shortcuts.available { controller.message = shortcutUnavailable }
        maintenance = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.history.prune() }
        }
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.popover.isShown else { return }
                self.controller.refreshPermission()
            }
        }
        updateStatus()
        show()
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--shortcut-checks"), CommandLine.arguments.count > index + 1 {
            DevelopmentChecks.runShortcutChecks(to: CommandLine.arguments[index + 1])
        }
        if let index = CommandLine.arguments.firstIndex(of: "--diagnostics"), CommandLine.arguments.count > index + 1 {
            popover.animates = false
            let originalMessage = controller.message
            controller.previewPhase(.typing(37, 100), targetName: "Test Editor")
            let progressVisible = item.button?.title == " 37%"
            controller.previewPhase(.typing(100, 100))
            let completionVisible = item.button?.title == " 100%"
            item.button?.performClick(nil)
            let clickAborts = !controller.busy
            let abortNamesTarget = controller.message == "Aborted typing in Test Editor."
            controller.previewPhase(.countdown(5))
            shortcuts.action?()
            let shortcutCancelsCountdown = !controller.busy && popover.isShown
            shortcuts.action?()
            let shortcutCloses = !popover.isShown
            shortcuts.action?()
            let shortcutOpens = popover.isShown
            controller.previewPhase(.typing(1, 100), targetName: "Test Editor")
            shortcuts.action?()
            let shortcutCancelsTyping = !controller.busy && popover.isShown
            controller.message = originalMessage
            DevelopmentChecks.run(to: CommandLine.arguments[index + 1], statusChecks: ["shortcutCancelsCountdown": shortcutCancelsCountdown, "shortcutCloses": shortcutCloses, "shortcutOpens": shortcutOpens, "shortcutCancelsTyping": shortcutCancelsTyping, "percentageVisible": progressVisible, "hundredPercentVisible": completionVisible, "statusClickAborts": clickAborts, "abortNamesTarget": abortNamesTarget])
        }
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let rootView = self?.popover.contentViewController?.view else { return }
                let view = rootView.window?.attachedSheet?.contentView ?? rootView
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
        }
        #endif
    }
    private func installEditingMenu() {
        let menu = NSMenu()
        let application = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Autotyper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = appMenu
        menu.addItem(application)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }
    @objc private func clicked() {
        if controller.busy { controller.abort(); return }
        toggle()
    }
    private func toggle() { if popover.isShown { popover.performClose(nil) } else { show() } }
    private func show() {
        guard let button = item.button else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        if previousApp?.processIdentifier == ProcessInfo.processInfo.processIdentifier { previousApp = nil }
        history.prune(); controller.refreshPermission()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.popover.contentViewController?.view else { return }
            @MainActor func findEditor(_ view: NSView) -> NSTextView? {
                if let editor = view as? NSTextView { return editor }
                return view.subviews.lazy.compactMap { findEditor($0) }.first
            }
            if let editor = findEditor(view) { view.window?.makeFirstResponder(editor) }
        }
    }
    private func updateStatus() {
        guard let button = item.button else { return }
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        switch controller.phase {
        case .idle:
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Autotyper")
            button.title = ""
            button.toolTip = shortcuts.shortcut.map { "Autotyper · Open \($0.title)" } ?? "Autotyper"
        case .countdown(let seconds):
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Countdown")
            button.title = " \(seconds)s"
            button.toolTip = "Click to cancel countdown"
        case .typing(let sent, let total):
            button.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop typing")
            button.title = " \(Int(Double(sent) / Double(total) * 100))%"
            button.toolTip = "Typing · Click or hold a modifier key to stop"
        }
        button.imagePosition = .imageLeading
    }
    func applicationWillTerminate(_ notification: Notification) { controller.abort(); shortcuts.stop() }
}
