import AppKit
import SwiftUI

struct ShortcutSettingsView: View {
    var shortcuts: GlobalShortcuts
    @Environment(\.dismiss) private var dismiss
    @State private var recording = false
    @State private var monitor: Any?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("App Shortcut").font(.headline)
            HStack(spacing: 0) {
                Button { startRecording() } label: {
                    Text(recording ? "Press a shortcut…" : shortcuts.shortcut?.title ?? " ")
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(recording ? "Recording shortcut" : shortcuts.shortcut?.title ?? "Record app shortcut")
                if shortcuts.shortcut != nil {
                    Button {
                        stopRecording()
                        error = nil
                        shortcuts.clear()
                    } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("Clear shortcut").accessibilityLabel("Clear shortcut")
                        .padding(.trailing, 10)
                }
            }
            .frame(width: 220)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            Text("Click to record a new shortcut. Press Escape to cancel recording.")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("Restore Default") { save(.standard) }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 410)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        stopRecording()
        recording = true
        error = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                if event.keyCode == 53 && event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
                    stopRecording()
                } else if let shortcut = AppShortcut.capture(event) {
                    save(shortcut)
                } else {
                    error = "Include Command, Control, or Option."
                }
            }
            return nil
        }
    }

    private func save(_ shortcut: AppShortcut) {
        if shortcuts.rebind(shortcut) {
            error = nil
            stopRecording()
        } else {
            error = "That shortcut is unavailable. Choose another combination."
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
