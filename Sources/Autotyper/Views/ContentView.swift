import SwiftUI
import AppKit

struct ContentView: View {
    @Bindable var controller: TypingController
    @Bindable var history: HistoryStore
    @State private var tab = 0
    @State private var clearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard.badge.ellipsis").font(.system(size: 26)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autotyper").font(.title2.weight(.semibold))
                    Text("Your words, wherever you need them.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Toggle("Allow secure/password fields", isOn: $controller.allowSecureFields)
                    Divider()
                    Toggle("Save history locally", isOn: $history.enabled)
                    Picker("Keep history for", selection: $history.days) {
                        ForEach([1, 3, 7, 14, 30], id: \.self) { days in Text("\(days) days").tag(days) }
                    }
                    Divider()
                    Text("Open: ⌃⌥⌘T")
                    Text("Stop: ⌃⌥⌘X")
                    Divider()
                    Button("Quit Autotyper") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "gearshape") }
                .menuStyle(.borderlessButton).fixedSize().help("Preferences and shortcuts")
            }
            Picker("View", selection: $tab) {
                Text("Compose").tag(0)
                Text("History · \(history.entries.count)").tag(1)
            }.pickerStyle(.segmented).labelsHidden()
            if tab == 0 { composer } else { historyView }
            Divider()
            HStack {
                Label("On this Mac only", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Open ⌃⌥⌘T · Stop ⌃⌥⌘X").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(20).frame(width: 430, height: 580)
        .background(.regularMaterial)
        .alert("Clear all history?", isPresented: $clearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) { history.clear() }
        } message: { Text("This removes every saved text from this Mac.") }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TEXT TO TYPE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    if let text = NSPasteboard.general.string(forType: .string) { controller.text = text }
                } label: { Label("Paste", systemImage: "clipboard") }.buttonStyle(.borderless)
                Button { controller.text = "" } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless).help("Clear composer").disabled(controller.text.isEmpty)
            }
            ZStack(alignment: .topLeading) {
                PlainTextEditor(text: $controller.text)
                    .padding(7)
                    .accessibilityLabel("Text to type")
                if controller.text.isEmpty {
                    Text("Type or paste anything…\nParagraphs, lists, symbols, emoji.")
                        .foregroundStyle(.tertiary).font(.system(size: 13)).padding(12)
                        .allowsHitTesting(false)
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
            .frame(minHeight: 130)
            HStack {
                Text("\(controller.text.count.formatted()) characters").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("Compatibility pace", isOn: $controller.gentle).toggleStyle(.checkbox).font(.caption)
                    .help("50 characters/second for slower apps. Default: about 250/second.")
            }
            HStack {
                Text("Start after").font(.subheadline)
                Picker("Start delay", selection: $controller.delay) {
                    ForEach([3, 5, 10, 15, 30], id: \.self) { Text("\($0)s").tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            if controller.allowSecureFields {
                Text("Secure-field typing is on · history is skipped for this run.").font(.caption).foregroundStyle(.secondary)
            }
            if !controller.trusted {
                Button { controller.requestPermission() } label: {
                    Label("Open Accessibility Settings", systemImage: "hand.raised")
                }.buttonStyle(.borderless)
            }
            if let error = history.error { Text(error).font(.caption).foregroundStyle(.red) }
            Text(controller.message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button {
                if controller.busy { controller.abort() } else { controller.start(history: history) }
            } label: {
                HStack {
                    Spacer()
                    Label(controller.busy ? "Stop typing" : "Start countdown", systemImage: controller.busy ? "stop.fill" : "play.fill")
                    Spacer()
                }.padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(controller.text.isEmpty && !controller.busy)
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Kept for \(history.days) days · up to 100 texts").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear all", role: .destructive) { clearConfirmation = true }
                    .buttonStyle(.borderless).disabled(history.entries.isEmpty)
            }
            if let error = history.error { Text(error).font(.caption).foregroundStyle(.red) }
            if history.entries.isEmpty {
                ContentUnavailableView("No saved text", systemImage: "clock", description: Text("Texts appear here when you start a countdown."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(history.entries) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    controller.text = entry.text; tab = 0
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(entry.text).lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(.primary)
                                        Text(entry.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).help("Load this text into the composer")
                                Button { history.remove(entry) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless).foregroundStyle(.secondary).help("Delete this text")
                            }.padding(.vertical, 12)
                            Divider()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Text(history.enabled ? "Select an entry to use it again. History is stored locally, unencrypted." : "History saving is off. Existing entries still expire automatically.")
                .font(.caption).foregroundStyle(.secondary)
        }.frame(maxHeight: .infinity)
    }
}
