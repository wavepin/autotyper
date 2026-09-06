import Foundation
import Observation
import AutotyperCore

@MainActor @Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    var error: String?
    var days: Int {
        didSet { UserDefaults.standard.set(days, forKey: "historyDays"); prune() }
    }
    var enabled: Bool {
        didSet { UserDefaults.standard.set(!enabled, forKey: "historyDisabled") }
    }
    private let file: URL
    init() {
        let saved = UserDefaults.standard.integer(forKey: "historyDays")
        days = [1, 3, 7, 14, 30].contains(saved) ? saved : 7
        enabled = !UserDefaults.standard.bool(forKey: "historyDisabled")
        file = URL.applicationSupportDirectory.appending(path: "Autotyper/history.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do { entries = try JSONDecoder().decode([HistoryEntry].self, from: Data(contentsOf: file)) }
            catch { self.error = "History could not be read: \(error.localizedDescription)" }
        }
        prune()
    }
    func add(_ text: String) {
        guard enabled else { return }
        entries.removeAll { $0.text == text }
        entries.insert(HistoryEntry(text: text), at: 0)
        entries = HistoryPolicy.retained(entries, days: days)
        save()
    }
    func remove(_ entry: HistoryEntry) { entries.removeAll { $0.id == entry.id }; save() }
    func clear() { entries = []; save() }
    func prune() {
        let kept = HistoryPolicy.retained(entries, days: days)
        guard kept != entries else { return }
        entries = kept
        save()
    }
    private func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            self.error = nil
        } catch { self.error = "History could not be saved: \(error.localizedDescription)" }
    }
}
