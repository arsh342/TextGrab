import Foundation
import Carbon
import AppKit
import Combine

protocol ShortcutService {
    func register() throws
    func unregister()
    var isRegistered: Bool { get }
}

enum ShortcutAction: Equatable {
    case selection
    case savedRegion
}

final class GlobalShortcutManager: ObservableObject, ShortcutService {
    @Published var isRegistered: Bool = false
    @Published var currentShortcut: String = "⌘⇧2"
    @Published var currentSavedShortcut: String = "⌘⌥2"

    private var hotKeyRef: EventHotKeyRef?
    private var savedHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private var shortcutKeyCode: UInt32 = 19 // '2' key
    private var shortcutModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    private let defaults = UserDefaults.standard
    private let keyCodeDefaultsKey = "shortcutKeyCode"
    private let modifiersDefaultsKey = "shortcutModifiers"
    private let savedKeyCodeDefaultsKey = "savedShortcutKeyCode"
    private let savedModifiersDefaultsKey = "savedShortcutModifiers"

    init() {
        if defaults.object(forKey: keyCodeDefaultsKey) != nil {
            shortcutKeyCode = UInt32(defaults.integer(forKey: keyCodeDefaultsKey))
        }
        if defaults.object(forKey: modifiersDefaultsKey) != nil {
            shortcutModifiers = UInt32(defaults.integer(forKey: modifiersDefaultsKey))
        }
        if defaults.object(forKey: savedKeyCodeDefaultsKey) != nil {
            savedShortcutKeyCode = UInt32(defaults.integer(forKey: savedKeyCodeDefaultsKey))
        }
        if defaults.object(forKey: savedModifiersDefaultsKey) != nil {
            savedShortcutModifiers = UInt32(defaults.integer(forKey: savedModifiersDefaultsKey))
        }
        currentShortcut = defaults.string(forKey: "shortcut") ?? currentShortcut
        currentSavedShortcut = defaults.string(forKey: "savedShortcut") ?? currentSavedShortcut
    }

    deinit {
        unregister()
    }

    func register() throws {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData else {
                return OSStatus(eventNotHandledErr)
            }
            _ = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            var actualType = EventParamType(0)
            var actualSize = 0
            GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                &actualType,
                MemoryLayout<EventHotKeyID>.size,
                &actualSize,
                &hotKeyID
            )

            let notification: Notification.Name = hotKeyID.id == 2
                ? .triggerSavedCapture
                : .triggerCapture
            NotificationCenter.default.post(name: notification, object: nil)
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        guard status == noErr else {
            Logger.shared.error("Failed to install event handler: \(status)")
            throw TextGrabError.shortcutRegistrationFailed("Failed to install event handler")
        }

        let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode("TGKB")), id: 1)
        let registerStatus = RegisterEventHotKey(
            shortcutKeyCode,
            shortcutModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            Logger.shared.error("Failed to register hotkey: \(registerStatus)")
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                eventHandler = nil
            }
            throw TextGrabError.shortcutRegistrationFailed("Failed to register hotkey (code: \(registerStatus))")
        }

        guard shortcutKeyCode != savedShortcutKeyCode || shortcutModifiers != savedShortcutModifiers else {
            unregister()
            throw TextGrabError.shortcutRegistrationFailed("Capture shortcuts must be different")
        }

        let savedHotKeyID = EventHotKeyID(signature: OSType(fourCharCode("TGKB")), id: 2)
        let savedRegisterStatus = RegisterEventHotKey(
            savedShortcutKeyCode,
            savedShortcutModifiers,
            savedHotKeyID,
            GetApplicationEventTarget(),
            0,
            &savedHotKeyRef
        )

        guard savedRegisterStatus == noErr else {
            Logger.shared.error("Failed to register saved-area hotkey: \(savedRegisterStatus)")
            unregister()
            throw TextGrabError.shortcutRegistrationFailed("Failed to register saved-area hotkey (code: \(savedRegisterStatus))")
        }

        isRegistered = true
        Logger.shared.info("Global shortcut registered: \(currentShortcut)")
    }

    func unregister() {
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }

        if let hotKey = savedHotKeyRef {
            UnregisterEventHotKey(hotKey)
            savedHotKeyRef = nil
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }

        isRegistered = false
        Logger.shared.info("Global shortcut unregistered")
    }

    func updateShortcut(keyCode: UInt32, modifiers: UInt32, displayString: String) throws {
        try updateShortcut(.selection, keyCode: keyCode, modifiers: modifiers, displayString: displayString)
    }

    func updateShortcut(_ action: ShortcutAction, keyCode: UInt32, modifiers: UInt32, displayString: String) throws {
        unregister()

        let previousKeyCode = action == .selection ? shortcutKeyCode : savedShortcutKeyCode
        let previousModifiers = action == .selection ? shortcutModifiers : savedShortcutModifiers
        let previousDisplayString = action == .selection ? currentShortcut : currentSavedShortcut

        if action == .selection {
            shortcutKeyCode = keyCode
            shortcutModifiers = modifiers
            currentShortcut = displayString
        } else {
            savedShortcutKeyCode = keyCode
            savedShortcutModifiers = modifiers
            currentSavedShortcut = displayString
        }

        do {
            try register()
            if action == .selection {
                defaults.set(Int(shortcutKeyCode), forKey: keyCodeDefaultsKey)
                defaults.set(Int(shortcutModifiers), forKey: modifiersDefaultsKey)
                defaults.set(currentShortcut, forKey: "shortcut")
            } else {
                defaults.set(Int(savedShortcutKeyCode), forKey: savedKeyCodeDefaultsKey)
                defaults.set(Int(savedShortcutModifiers), forKey: savedModifiersDefaultsKey)
                defaults.set(currentSavedShortcut, forKey: "savedShortcut")
            }
        } catch {
            if action == .selection {
                shortcutKeyCode = previousKeyCode
                shortcutModifiers = previousModifiers
                currentShortcut = previousDisplayString
            } else {
                savedShortcutKeyCode = previousKeyCode
                savedShortcutModifiers = previousModifiers
                currentSavedShortcut = previousDisplayString
            }
            do {
                try register()
            } catch {
                Logger.shared.error("Failed to restore previous shortcuts: \(error.localizedDescription)")
            }
            Logger.shared.error("Failed to re-register shortcut: \(error)")
            throw error
        }
    }

    private var savedShortcutKeyCode: UInt32 = 19
    private var savedShortcutModifiers: UInt32 = UInt32(cmdKey | optionKey)
}

private func fourCharCode(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for char in string.utf8 {
        result = (result << 8) + UInt32(char)
    }
    return result
}
