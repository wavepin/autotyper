import Foundation
import CoreGraphics
import AutotyperCore

@main
struct AutotyperChecks {
    static func main() {
        let checks = AutotyperChecks()
        checks.testUnicodeRoundTrip()
        checks.testNewlineNormalization()
        checks.testExpiryAndOrdering()
        checks.testKeyboardEventEncoding()
        checks.testMultilineEvents()
        print("PASS: Unicode round trips, long text, escapes, line endings, expiry, ordering, history cap, and CGEvent encoding.")
    }
    func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #file, line: UInt = #line) {
        precondition(lhs == rhs, "Equality check failed", file: file, line: line)
    }
    func expectTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
        precondition(value, "Condition failed", file: file, line: line)
    }
    func testMultilineEvents() {
        let packets = TextPayload.events("Test\r\nwith\n\nlinebreak\n")
        for mode in LineBreakMode.allCases {
            let pairs = packets.map { KeyboardEvents.pair(units: $0, lineBreakMode: mode, source: nil)! }
            let returns = pairs.filter { $0.down.getIntegerValueField(.keyboardEventKeycode) == 36 }
            expectEqual(returns.count, 4)
            for pair in returns {
                expectEqual(pair.down.flags.contains(.maskShift), mode == .shiftReturn)
                expectTrue(pair.up.flags.isEmpty)
                var count = 0
                var characters = [UInt16](repeating: 0, count: 20)
                pair.down.keyboardGetUnicodeString(maxStringLength: 20, actualStringLength: &count, unicodeString: &characters)
                expectEqual(Array(characters.prefix(count)), [13])
            }
            expectTrue(pairs.filter { $0.down.getIntegerValueField(.keyboardEventKeycode) == 0 }.allSatisfy { $0.down.flags.isEmpty })
        }
        let literal = TextPayload.events("\\n")
        expectTrue(literal.allSatisfy { KeyboardEvents.pair(units: $0, lineBreakMode: .shiftReturn, source: nil)!.down.getIntegerValueField(.keyboardEventKeycode) == 0 })
    }
    func testKeyboardEventEncoding() {
        for units in TextPayload.events("A\n\t• 中文 👨‍👩‍👧‍👦 👍🏽") {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
            units.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress) }
            var actual = 0
            var decoded = [UInt16](repeating: 0, count: 20)
            event.keyboardGetUnicodeString(maxStringLength: 20, actualStringLength: &actual, unicodeString: &decoded)
            expectEqual(Array(decoded.prefix(actual)), units)
        }
    }
    func testUnicodeRoundTrip() {
        let cases = ["", "Hi", "literal \\n \\t \\\"", "• One\n\t◦ Two\n三", "👨‍👩‍👧‍👦 🇺🇸 👍🏽 é e\u{301}", String(repeating: "Long paragraph. 🦊\n", count: 10000), "a" + String(repeating: "\u{301}", count: 60)]
        for text in cases {
            let events = TextPayload.events(text)
            expectEqual(String(decoding: events.flatMap { $0 }, as: UTF16.self), text)
            expectTrue(events.allSatisfy { !$0.isEmpty && $0.count <= 20 })
            for event in events {
                expectEqual(Array(String(decoding: event, as: UTF16.self).utf16), event)
            }
        }
    }
    func testNewlineNormalization() {
        expectEqual(String(decoding: TextPayload.events("a\r\nb\rc\n").flatMap { $0 }, as: UTF16.self), "a\nb\nc\n")
    }
    func testExpiryAndOrdering() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let recent = HistoryEntry(text: "new", date: now)
        let boundary = HistoryEntry(text: "old", date: now.addingTimeInterval(-7 * 86400))
        expectEqual(HistoryPolicy.retained([boundary, recent], days: 7, now: now), [recent])
        let many = (0..<120).map { HistoryEntry(text: String($0), date: now.addingTimeInterval(-Double($0))) }
        expectEqual(HistoryPolicy.retained(many.reversed(), days: 7, now: now), Array(many.prefix(100)))
    }
}
