import CoreGraphics
import Foundation

enum InputTriggerKey: String, CaseIterable, Identifiable {
    case option
    case command
    case control
    case shift
    case function

    var id: String { rawValue }

    var title: String {
        switch self {
        case .option: "Option (⌥)"
        case .command: "Command (⌘)"
        case .control: "Control (⌃)"
        case .shift: "Shift (⇧)"
        case .function: "Fn / Globe"
        }
    }

    var keyCodes: Set<Int64> {
        switch self {
        case .option: [0x3A, 0x3D]
        case .command: [0x37, 0x36]
        case .control: [0x3B, 0x3E]
        case .shift: [0x38, 0x3C]
        case .function: [0x3F]
        }
    }

    var primaryKeyCode: CGKeyCode {
        CGKeyCode(keyCodes.min() ?? 0x3A)
    }

    var flag: CGEventFlags {
        switch self {
        case .option: .maskAlternate
        case .command: .maskCommand
        case .control: .maskControl
        case .shift: .maskShift
        case .function: .maskSecondaryFn
        }
    }
}

enum Key {
    /// Lets the event tap distinguish vRemoter-generated events from physical
    /// keyboards, Bluetooth buttons, and external remappers.
    static let syntheticMarker: Int64 = 0x4D_49_52_42 // "MIRB"

    static func triggerDown(_ trigger: InputTriggerKey = AppStorage.inputTriggerKey) {
        post(trigger: trigger, keyDown: true)
    }

    static func triggerUp(_ trigger: InputTriggerKey = AppStorage.inputTriggerKey) {
        post(trigger: trigger, keyDown: false)
    }

    /// A deliberate short modifier click for Doubao's toggle mode.
    static func triggerTap(
        _ trigger: InputTriggerKey = AppStorage.inputTriggerKey,
        completion: (() -> Void)? = nil
    ) {
        triggerDown(trigger)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            triggerUp(trigger)
            completion?()
        }
    }

    private static func post(trigger: InputTriggerKey, keyDown: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: trigger.primaryKeyCode,
            keyDown: keyDown
        ) else { return }
        event.flags = keyDown ? trigger.flag : []
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.post(tap: .cghidEventTap)
        print(
            "[KEY] synthetic \(trigger.title) " +
            (keyDown ? "DOWN" : "UP")
        )
    }
}

/// Translates recognition transitions to the user's existing shortcut.
/// Fn hold is an application preference; established toggle shortcuts stay intact.
final class RecognitionTrigger {
    private let functionIsHold: () -> Bool
    private let key: () -> InputTriggerKey
    private let down: (InputTriggerKey) -> Void
    private let up: (InputTriggerKey) -> Void
    private let tap: (InputTriggerKey) -> Void
    private var functionHeld = false

    init(
        functionIsHold: @escaping () -> Bool = { AppStorage.functionHoldEnabled },
        key: @escaping () -> InputTriggerKey = { AppStorage.inputTriggerKey },
        down: @escaping (InputTriggerKey) -> Void = { Key.triggerDown($0) },
        up: @escaping (InputTriggerKey) -> Void = { Key.triggerUp($0) },
        tap: @escaping (InputTriggerKey) -> Void = { Key.triggerTap($0) }
    ) {
        self.functionIsHold = functionIsHold
        self.key = key
        self.down = down
        self.up = up
        self.tap = tap
    }

    func toggle() {
        // Complete the event pair even if the setting changes mid-session.
        if functionHeld {
            release()
            return
        }
        let current = key()
        guard functionIsHold(), current == .function else {
            tap(current)
            return
        }
        functionHeld = true
        down(.function)
    }

    /// Only releases a synthetic Fn-down issued by this instance.
    func release() {
        guard functionHeld else { return }
        functionHeld = false
        up(.function)
    }
}
