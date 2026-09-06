import CoreGraphics

public enum LineBreakMode: String, CaseIterable, Sendable {
    case shiftReturn
    case returnKey

    public var title: String {
        switch self {
        case .shiftReturn: "Shift–Return (chat fields)"
        case .returnKey: "Return (documents)"
        }
    }
}

public enum KeyboardEvents {
    /// A line break must be a real Return event: Chromium and many native
    /// editors ignore an LF attached to the arbitrary key used for Unicode.
    public static func pair(units: [UInt16], lineBreakMode: LineBreakMode, source: CGEventSource?) -> (down: CGEvent, up: CGEvent)? {
        let isLineBreak = units == [10]
        let key: CGKeyCode = isLineBreak ? 36 : 0
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return nil }
        down.flags = isLineBreak && lineBreakMode == .shiftReturn ? .maskShift : []
        // Explicitly clear the synthetic Shift so the following character is
        // unmodified and cancellation cannot leave a modifier logically held.
        up.flags = []
        let characters: [UInt16] = isLineBreak ? [13] : units
        characters.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        return (down, up)
    }
}
