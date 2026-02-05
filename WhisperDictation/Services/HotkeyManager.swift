import Foundation
import Carbon
import Cocoa

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeyCallback: ((Bool) -> Void)?
    private var historyHotkeyCallback: (() -> Void)?
    private var styleCycleCallback: (() -> Void)?

    private let stateQueue = DispatchQueue(label: "com.whisperdictation.hotkeystate")
    private var _isPressed = false
    private var isPressed: Bool {
        get { stateQueue.sync { _isPressed } }
        set { stateQueue.sync { _isPressed = newValue } }
    }
    private let settings = AppSettings.shared

    func registerHistoryHotkey(callback: @escaping () -> Void) {
        historyHotkeyCallback = callback
    }

    func registerStyleCycleHotkey(callback: @escaping () -> Void) {
        styleCycleCallback = callback
    }

    func startMonitoring(callback: @escaping (Bool) -> Void) {
        NSLog("🔑 HotkeyManager: startMonitoring called")
        NSLog("🔑 Configured hotkey code: \(settings.hotkey)")
        NSLog("🔑 Recording mode: \(settings.recordingMode)")

        hotkeyCallback = callback

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("❌ HotkeyManager: FAILED to create event tap - Accessibility permission may not be granted!")
            NSLog("❌ AXIsProcessTrusted: \(AXIsProcessTrusted())")
            return
        }

        self.eventTap = eventTap

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        NSLog("✅ HotkeyManager: Event tap created and enabled successfully")
    }

    private var previousCapsLockState = false

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check for Cmd+Shift+S (Style cycle hotkey)
        if keyCode == 0x01 && flags.contains(.maskCommand) && flags.contains(.maskShift) && type == .keyDown {
            NSLog("🔔 STYLE CYCLE HOTKEY DETECTED! Cmd+Shift+S")
            styleCycleCallback?()
            return nil // Consume the event
        }

        // Check for Cmd+Shift+H (History hotkey)
        if keyCode == 0x04 && flags.contains(.maskCommand) && flags.contains(.maskShift) && type == .keyDown {
            NSLog("🔔 HISTORY HOTKEY DETECTED! Cmd+Shift+H")
            historyHotkeyCallback?()
            return nil // Consume the event
        }

        // Check if it's our configured hotkey (default: CapsLock = 57)
        if keyCode == settings.hotkey {
            NSLog("🔔 HOTKEY DETECTED! KeyCode: \(keyCode), Event Type: \(type.rawValue)")

            let isKeyDown: Bool
            if settings.hotkey == 57 { // CapsLock special handling
                // For CapsLock, detect state CHANGE not current state
                let currentCapsLockState = event.flags.contains(.maskAlphaShift)
                NSLog("   CapsLock state: previous=\(previousCapsLockState), current=\(currentCapsLockState)")

                // Detect press: state changed
                isKeyDown = currentCapsLockState != previousCapsLockState
                previousCapsLockState = currentCapsLockState

                NSLog("   CapsLock press detected: \(isKeyDown)")
            } else {
                // Regular key handling
                isKeyDown = (type == .keyDown)
                NSLog("   Regular key - isKeyDown: \(isKeyDown)")
            }

            if settings.recordingMode == .toggle {
                // Toggle mode: only trigger on key down
                if isKeyDown {
                    NSLog("   ✅ Triggering callback with TRUE (toggle mode)")
                    hotkeyCallback?(true)
                    return nil // Consume the event
                }
            } else {
                // Hold mode: trigger on press and release
                if isKeyDown && !isPressed {
                    isPressed = true
                    NSLog("   ✅ Triggering callback with TRUE (hold mode)")
                    hotkeyCallback?(true)
                    return nil
                } else if !isKeyDown && isPressed {
                    isPressed = false
                    NSLog("   ✅ Triggering callback with FALSE (hold mode)")
                    hotkeyCallback?(false)
                    return nil
                }
            }

            return nil // Consume hotkey event
        }

        return Unmanaged.passUnretained(event)
    }

    func stopMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        hotkeyCallback = nil
        historyHotkeyCallback = nil
        styleCycleCallback = nil
    }

    deinit {
        stopMonitoring()
    }
}
