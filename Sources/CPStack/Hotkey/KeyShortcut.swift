import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: a physical key plus modifier flags.
nonisolated struct KeyShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifierFlags: UInt

    /// ⌘⇧V — the closest macOS counterpart of Win+V.
    static let `default` = KeyShortcut(keyCode: UInt16(kVK_ANSI_V), modifiers: [.command, .shift])

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifiers.intersection(Self.relevantModifiers).rawValue
    }

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierFlags) }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayString: String {
        modifiers.symbols + KeyCodeTranslator.displayName(for: keyCode)
    }

    /// Plain letters would break normal typing, so a shortcut needs ⌘, ⌥ or ⌃ —
    /// except function keys, which are fine on their own.
    var isValid: Bool {
        !modifiers.intersection([.command, .option, .control]).isEmpty
            || KeyCodeTranslator.isFunctionKey(keyCode)
    }
}

extension NSEvent.ModifierFlags {
    nonisolated var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}
