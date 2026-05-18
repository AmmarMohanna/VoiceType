import Carbon
import Foundation

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var actions: [UInt32: () -> Void] = [:]

    private init() {}

    deinit {
        unregister()
    }

    func registerOptionSpace(action: @escaping () -> Void) {
        register(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), id: 1, action: action)
    }

    func registerControlR(action: @escaping () -> Void) {
        register(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey), id: 2, action: action)
    }

    func unregister() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
        actions.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func register(
        keyCode: UInt32,
        modifiers: UInt32,
        id: UInt32,
        action: @escaping () -> Void
    ) {
        installEventHandlerIfNeeded()

        if let existingRef = hotKeyRefs[id] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs[id] = nil
        }

        actions[id] = action

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("VTyp"), id: id)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if let hotKeyRef {
            hotKeyRefs[id] = hotKeyRef
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return status
                }

                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                manager.actions[hotKeyID.id]?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}
