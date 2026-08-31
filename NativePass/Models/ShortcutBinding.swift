import AppKit
import Carbon
import Foundation
import SwiftUI

/// A keyboard shortcut persisted for NativePass actions.
struct ShortcutBinding: Codable, Equatable, Hashable, Sendable {
    /// Hardware key code (`kVK_*`).
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags` raw value (device-independent bits only).
    var modifierFlags: UInt
    /// Lowercase character for SwiftUI `KeyEquivalent` when applicable.
    var keyCharacter: String

    var nsModifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
            .intersection([.command, .shift, .option, .control])
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        let flags = nsModifierFlags
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    var swiftUIModifiers: SwiftUI.EventModifiers {
        var value: SwiftUI.EventModifiers = []
        let flags = nsModifierFlags
        if flags.contains(.command) { value.insert(.command) }
        if flags.contains(.shift) { value.insert(.shift) }
        if flags.contains(.option) { value.insert(.option) }
        if flags.contains(.control) { value.insert(.control) }
        return value
    }

    var keyEquivalent: KeyEquivalent {
        if keyCharacter == "space" {
            return KeyEquivalent(" ")
        }
        let scalar = keyCharacter.first ?? "?"
        return KeyEquivalent(scalar)
    }

    var displayString: String {
        var parts: [String] = []
        let flags = nsModifierFlags
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(Self.displayKey(keyCode: keyCode, character: keyCharacter))
        return parts.joined()
    }

    static let quickAccessDefault = ShortcutBinding(
        keyCode: UInt16(kVK_ANSI_P),
        modifierFlags: NSEvent.ModifierFlags([.option, .command]).rawValue,
        keyCharacter: "p"
    )

    init(keyCode: UInt16, modifierFlags: UInt, keyCharacter: String) {
        self.keyCode = keyCode
        self.modifierFlags = NSEvent.ModifierFlags(rawValue: modifierFlags)
            .intersection([.command, .shift, .option, .control])
            .rawValue
        self.keyCharacter = keyCharacter.lowercased()
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !flags.isEmpty else { return nil }

        let keyCode = UInt16(event.keyCode)
        if keyCode == UInt16(kVK_Escape) { return nil }

        let character: String
        if let raw = event.charactersIgnoringModifiers?.lowercased(),
           let first = raw.first,
           first.isLetter || first.isNumber || first == " " {
            character = first == " " ? "space" : String(first)
        } else if let mapped = Self.character(forKeyCode: keyCode) {
            character = mapped
        } else {
            return nil
        }

        self.init(keyCode: keyCode, modifierFlags: flags.rawValue, keyCharacter: character)
    }

    private static func displayKey(keyCode: UInt16, character: String) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            if character == "space" { return "Space" }
            return character.uppercased()
        }
    }

    private static func character(forKeyCode keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "space"
        default: return nil
        }
    }
}
