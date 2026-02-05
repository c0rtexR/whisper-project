import Foundation
import Cocoa
import ApplicationServices

class TextInjector {
    static func insertText(_ text: String) {
        // Method 1: Simulate typing via CGEvent (most reliable)
        DispatchQueue.main.async {
            // Small delay to ensure focus is ready
            usleep(50000) // 50ms

            // Type each character
            for char in text {
                if let keyCode = KeyCodeMapper.keyCode(for: char) {
                    let (code, needsShift) = keyCode

                    // Key down
                    if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true) {
                        if needsShift {
                            keyDownEvent.flags = .maskShift
                        }
                        keyDownEvent.post(tap: .cghidEventTap)
                    }

                    // Key up
                    if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) {
                        if needsShift {
                            keyUpEvent.flags = .maskShift
                        }
                        keyUpEvent.post(tap: .cghidEventTap)
                    }

                    usleep(1000) // 1ms between characters
                }
            }
        }
    }

    static func deleteText(count: Int) {
        // Simulate backspace key presses
        DispatchQueue.main.async {
            usleep(50000) // 50ms delay

            for _ in 0..<count {
                // Backspace key code is 0x33
                if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) {
                    keyDownEvent.post(tap: .cghidEventTap)
                }

                if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: false) {
                    keyUpEvent.post(tap: .cghidEventTap)
                }

                usleep(5000) // 5ms between backspaces
            }
        }
    }

    static func insertTextViaClipboard(_ text: String) {
        // Method 2: Use clipboard + paste (faster but overwrites clipboard)
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let cmdV = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) // V key
            cmdV?.flags = .maskCommand
            cmdV?.post(tap: .cghidEventTap)

            let cmdVUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
            cmdVUp?.flags = .maskCommand
            cmdVUp?.post(tap: .cghidEventTap)

            // Restore clipboard after a delay
            if let previous = previousContents {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }
}

// Helper to map characters to key codes
class KeyCodeMapper {
    static func keyCode(for character: Character) -> (CGKeyCode, Bool)? {
        let str = String(character).lowercased()
        let needsShift = character.isUppercase || "!@#$%^&*()_+{}|:\"<>?".contains(character)

        let keyMap: [String: CGKeyCode] = [
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
            "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
            "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
            "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
            "y": 0x10, "z": 0x06,
            "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
            " ": 0x31, ".": 0x2F, ",": 0x2B, "?": 0x2C, "!": 0x12,
            "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A,
            ";": 0x29, "'": 0x27, "`": 0x32, "/": 0x2C,
            "\n": 0x24, "\t": 0x30
        ]

        guard let code = keyMap[str] else {
            return nil
        }

        return (code, needsShift)
    }
}
