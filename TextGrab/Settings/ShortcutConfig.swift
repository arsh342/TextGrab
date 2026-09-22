import Foundation
import AppKit
import Carbon

struct ShortcutConfig: Codable {
    static let defaultShortcut = "⌘⇧2"
    static let defaultSavedShortcut = "⌘⌥2"
    static let defaultKeyCode: UInt32 = 19
    static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    static let defaultSavedModifiers: UInt32 = UInt32(cmdKey | optionKey)

    var shortcut: String = defaultShortcut
    var savedShortcut: String = defaultSavedShortcut
    var keyCode: UInt32 = defaultKeyCode
    var modifiers: UInt32 = defaultModifiers
    var savedKeyCode: UInt32 = defaultKeyCode
    var savedModifiers: UInt32 = defaultSavedModifiers

    static let defaultsKey = "ShortcutConfig"
}

extension ShortcutConfig {
    init(from defaults: UserDefaults) {
        self.shortcut = defaults.string(forKey: "shortcut") ?? Self.defaultShortcut
        self.savedShortcut = defaults.string(forKey: "savedShortcut") ?? Self.defaultSavedShortcut
        self.keyCode = UInt32(defaults.integer(forKey: "shortcutKeyCode"))
        self.modifiers = UInt32(defaults.integer(forKey: "shortcutModifiers"))
        self.savedKeyCode = UInt32(defaults.integer(forKey: "savedShortcutKeyCode"))
        self.savedModifiers = UInt32(defaults.integer(forKey: "savedShortcutModifiers"))
    }

    func save(to defaults: UserDefaults) {
        defaults.set(shortcut, forKey: "shortcut")
        defaults.set(savedShortcut, forKey: "savedShortcut")
        defaults.set(Int(keyCode), forKey: "shortcutKeyCode")
        defaults.set(Int(modifiers), forKey: "shortcutModifiers")
        defaults.set(Int(savedKeyCode), forKey: "savedShortcutKeyCode")
        defaults.set(Int(savedModifiers), forKey: "savedShortcutModifiers")
    }

    mutating func reset() {
        self = Self()
    }
}