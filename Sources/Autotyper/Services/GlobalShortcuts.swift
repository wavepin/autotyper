import Carbon

@MainActor
final class GlobalShortcuts {
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var action: ((UInt32) -> Void)?
    private(set) var available = true

    func register() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr else { return status }
            let owner = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { owner.action?(id.id) }
            return noErr
        }, 1, &event, context, &handler)
        available = result == noErr
        for (key, id) in [(UInt32(kVK_ANSI_T), UInt32(1)), (UInt32(kVK_ANSI_X), UInt32(2))] {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(key, UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: 0x41545950, id: id), GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { references.append(ref) } else { available = false }
        }
    }
}
