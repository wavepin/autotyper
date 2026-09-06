import Foundation

public enum TextPayload {
    // Never interpret literal backslash escapes. Normalize platform line endings only.
    public static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    public static func events(_ text: String) -> [[UInt16]] {
        normalized(text).flatMap { character -> [[UInt16]] in
            // CGEvent permits at most 20 UTF-16 code units. Keep ordinary graphemes
            // intact, and split unusually long clusters only at scalar boundaries.
            var result: [[UInt16]] = []
            var buffer: [UInt16] = []
            for scalar in character.unicodeScalars {
                let units = Array(String(scalar).utf16)
                if buffer.count + units.count > 20 {
                    result.append(buffer)
                    buffer = []
                }
                buffer.append(contentsOf: units)
            }
            if !buffer.isEmpty { result.append(buffer) }
            return result
        }
    }
}

public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let date: Date
    public init(id: UUID = UUID(), text: String, date: Date = Date()) {
        self.id = id; self.text = text; self.date = date
    }
}

public enum HistoryPolicy {
    public static func retained(_ entries: [HistoryEntry], days: Int, now: Date = Date()) -> [HistoryEntry] {
        let cutoff = now.addingTimeInterval(-Double(max(1, days)) * 86_400)
        return Array(entries.filter { $0.date > cutoff }.sorted { $0.date > $1.date }.prefix(100))
    }
}
