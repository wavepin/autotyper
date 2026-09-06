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
        popover.contentSize = NSSize(width: 430, height: 580)
        popover.contentViewController = NSHostingController(rootView: ContentView(controller: controller, history: history))
        controller.onChange = { [weak self] in self?.updateStatus() }
        controller.onStart = { [weak self] in
            guard let self else { return }
            self.popover.performClose(nil)
            self.previousApp?.activate(options: [])
        }
        shortcuts.action = { [weak self] id in
            guard let self else { return }
            if id == 2 { self.controller.abort() }
            else if self.controller.busy { self.controller.abort(); self.show() }
            else { self.toggle() }
        }
        shortcuts.register()
        if !shortcuts.available { controller.message = "A shortcut is already in use. You can still open and stop Autotyper from the menu bar." }
        maintenance = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.history.prune() }
        }
        updateStatus()
        show()
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let view = self?.popover.contentViewController?.view,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
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
    }
    private func updateStatus() {
        guard let button = item.button else { return }
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        switch controller.phase {
        case .idle:
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Autotyper")
            button.title = ""
            button.toolTip = "Autotyper · Open ⌃⌥⌘T"
        case .countdown(let seconds):
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Countdown")
            button.title = " \(seconds)s"
            button.toolTip = "Click to cancel countdown · ⌃⌥⌘X"
        case .typing(let sent, let total):
            button.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop typing")
            button.title = " \(Int(Double(sent) / Double(total) * 100))%"
            button.toolTip = "Typing · Click to stop immediately · ⌃⌥⌘X"
        }
        button.imagePosition = .imageLeading
    }
    func applicationWillTerminate(_ notification: Notification) { controller.abort() }
}
