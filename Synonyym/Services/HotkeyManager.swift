import Carbon.HIToolbox
import AppKit

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotkeyPressed: (() -> Void)?

    private(set) var currentKeyCode: UInt32 = UInt32(kVK_ANSI_S)
    private(set) var currentModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    private static let hotkeyID = EventHotKeyID(
        signature: OSType(0x5359_4E4F), // "SYNO"
        id: 1
    )

    func register() {
        let config = ShortcutConfig.load()
        register(keyCode: config.keyCode, modifiers: config.modifiers)
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        // Unregister existing hotkey (but keep the event handler)
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        currentKeyCode = keyCode
        currentModifiers = modifiers

        // Install Carbon event handler if not already installed
        if eventHandler == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.onHotkeyPressed?()
                }
                return noErr
            }

            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(
                GetApplicationEventTarget(),
                handler,
                1,
                &eventType,
                selfPtr,
                &eventHandler
            )
        }

        // Register the hotkey
        var hotkeyID = HotkeyManager.hotkeyID
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
