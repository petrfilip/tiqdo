import Carbon.HIToolbox
import AppKit
import OSLog

final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandlerRef: EventHandlerRef?
    private let logger = Logger(subsystem: "cz.fg.tiqdo", category: "GlobalShortcut")

    private init() {}

    @discardableResult
    func register(
        keyCode: UInt32 = UInt32(kVK_ANSI_Q),
        modifiers: UInt32 = UInt32(controlKey),
        handler: @escaping () -> Void
    ) -> Bool {
        unregister()
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var newEventHandlerRef: EventHandlerRef?

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { mgr.handler?() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &newEventHandlerRef
        )
        guard installStatus == noErr else {
            logFailure("InstallEventHandler", status: installStatus)
            return false
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x54515044), id: 1)
        var newHotKeyRef: EventHotKeyRef?

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )
        guard registerStatus == noErr else {
            if let ref = newEventHandlerRef {
                RemoveEventHandler(ref)
            }
            logFailure("RegisterEventHotKey", status: registerStatus)
            return false
        }

        self.handler = handler
        self.eventHandlerRef = newEventHandlerRef
        self.hotKeyRef = newHotKeyRef
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        handler = nil
    }

    private func logFailure(_ operation: String, status: OSStatus) {
        logger.error("\(operation, privacy: .public) failed with OSStatus \(Int(status), privacy: .public)")
    }
}
