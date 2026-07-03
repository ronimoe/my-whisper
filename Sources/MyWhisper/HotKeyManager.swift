import AppKit
import Carbon

/// Registers a system-wide hotkey via the Carbon RegisterEventHotKey API,
/// which works without Accessibility permission.
final class HotKeyManager {
    var onHotKeyDown: (() -> Void)?
    var onHotKeyUp: (() -> Void)?
    /// Fires on key-press only (release is ignored) for the secondary hotkey,
    /// e.g. Escape-to-cancel while recording.
    var onSecondaryDown: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var secondaryRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static let signature = OSType(0x4D59_5753) /* MYWS */

    func register(keyCode: UInt32, modifiers: UInt32) {
        installHandlerIfNeeded()
        update(keyCode: keyCode, modifiers: modifiers)
    }

    /// Swaps the active hotkey without reinstalling the event handler.
    func update(keyCode: UInt32, modifiers: UInt32) {
        suspend()
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
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

    /// Registers a second, independent hotkey (e.g. Escape) used only while
    /// recording. Must be paired with `unregisterSecondary()` once the
    /// condition that warranted it (recording) ends — a hotkey left
    /// registered globally would swallow that key system-wide.
    func registerSecondary(keyCode: UInt32, modifiers: UInt32) {
        installHandlerIfNeeded()
        unregisterSecondary()
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 2)
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &secondaryRef)
        if status != noErr {
            NSLog("MyWhisper: failed to register secondary hotkey (status %d)", status)
        }
    }

    /// Releases the secondary hotkey, if registered.
    func unregisterSecondary() {
        if let secondaryRef {
            UnregisterEventHotKey(secondaryRef)
            self.secondaryRef = nil
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

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return noErr }

            DispatchQueue.main.async {
                if hotKeyID.id == 1 {
                    if kind == UInt32(kEventHotKeyPressed) {
                        manager.onHotKeyDown?()
                    } else if kind == UInt32(kEventHotKeyReleased) {
                        manager.onHotKeyUp?()
                    }
                } else if hotKeyID.id == 2 {
                    if kind == UInt32(kEventHotKeyPressed) {
                        manager.onSecondaryDown?()
                    }
                }
            }
            return noErr
        }, 2, &eventTypes, selfPointer, &handlerRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let secondaryRef { UnregisterEventHotKey(secondaryRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
