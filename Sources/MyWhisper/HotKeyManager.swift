import AppKit
import Carbon

/// Registers a system-wide hotkey via the Carbon RegisterEventHotKey API,
/// which works without Accessibility permission.
final class HotKeyManager {
    var onHotKey: (() -> Void)?
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
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onHotKey?() }
            return noErr
        }, 1, &eventType, selfPointer, &handlerRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
