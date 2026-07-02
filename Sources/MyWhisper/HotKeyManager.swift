import AppKit
import Carbon

/// Registers a system-wide hotkey via the Carbon RegisterEventHotKey API,
/// which works without Accessibility permission.
final class HotKeyManager {
    var onHotKeyDown: (() -> Void)?
    var onHotKeyUp: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register(keyCode: UInt32, modifiers: UInt32) {
        installHandlerIfNeeded()
        update(keyCode: keyCode, modifiers: modifiers)
    }

    /// Swaps the active hotkey without reinstalling the event handler.
    func update(keyCode: UInt32, modifiers: UInt32) {
        suspend()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D59_5753) /* MYWS */, id: 1)
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("MyWhisper: failed to register global hotkey (status %d)", status)
        }
    }

    /// Temporarily releases the hotkey (used while recording a new one).
    func suspend() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                         eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                         eventKind: UInt32(kEventHotKeyReleased))
        ]

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            let kind = GetEventKind(event)
            DispatchQueue.main.async {
                if kind == UInt32(kEventHotKeyPressed) {
                    manager.onHotKeyDown?()
                } else if kind == UInt32(kEventHotKeyReleased) {
                    manager.onHotKeyUp?()
                }
            }
            return noErr
        }, 2, &eventTypes, selfPointer, &handlerRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
