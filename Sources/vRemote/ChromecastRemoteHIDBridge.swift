import Foundation
import AppKit
import IOKit.hid

private func chromecastRemoteMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceDidMatch(result: result, device: device)
}

private func chromecastRemoteRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceDidRemove(device)
}

private func chromecastRemoteInputReport(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context, let sender, result == kIOReturnSuccess, reportLength > 0 else {
        return
    }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .handleReport(
            device: Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue(),
            reportID: reportID,
            data: Data(bytes: report, count: reportLength)
        )
}

/// Connection monitor for the Google Chromecast Remote HID interface.
///
/// Its voice key does not expose a dependable HID key-down usage on macOS;
/// voice gestures are therefore handled by the remote's ATVV control stream.
final class ChromecastRemoteHIDBridge {
    static let vendorID = 0x18D1
    static let productIDs = [0x9450, 0x9451]

    var onConnectionChanged: ((Bool) -> Void)?
    var nativeMediaFilterAvailable: () -> Bool = { false }

    private var managers: [IOHIDManager] = []
    private var nativeMediaGate = ChromecastNativeMediaGate()
    private var devices: [IOHIDDevice: ChromecastRemoteReportState] = [:]
    private var remappingEnabled = RemoteMappingStore.shared.isEnabled(.chromecast)

    func start() {
        stop()
        for productID in Self.productIDs { startManager(productID: productID) }
    }

    private func startManager(productID: Int) {
        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        IOHIDManagerSetDeviceMatching(
            manager,
            [
                kIOHIDVendorIDKey: Self.vendorID,
                kIOHIDProductIDKey: productID,
            ] as CFDictionary
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            chromecastRemoteMatched,
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            chromecastRemoteRemoved,
            context
        )
        IOHIDManagerRegisterInputReportCallback(
            manager,
            chromecastRemoteInputReport,
            context
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        // Keep 9450's existing exclusive boundary across its collections.
        // 9451 is a keyboard device: macOS denies non-privileged seize. Its
        // native media events are filtered through the existing event tap.
        let openOptions = remappingEnabled && productID == 0x9450
            ? IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
            : IOOptionBits(kIOHIDOptionsTypeNone)
        let result = IOHIDManagerOpen(manager, openOptions)
        guard result == kIOReturnSuccess else {
            print(
                "[CAST-HID] manager open failed: " +
                String(format: "0x%08X", UInt32(bitPattern: result))
            )
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            return
        }
        managers.append(manager)
        print(String(format: "[CAST-HID] waiting for PID=0x%04x", productID))
    }

    func stop() {
        releaseAllButtons()
        devices.removeAll()
        onConnectionChanged?(false)

        for manager in managers {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        managers.removeAll()
    }

    func setRemappingEnabled(_ enabled: Bool) {
        guard remappingEnabled != enabled else { return }
        releaseAllButtons()
        remappingEnabled = enabled
        start()
    }

    fileprivate func deviceDidMatch(
        result: IOReturn,
        device: IOHIDDevice
    ) {
        guard result == kIOReturnSuccess, devices[device] == nil,
              let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int,
              Self.productIDs.contains(productID) else { return }
        // IOHIDManagerOpen already opened every current and future matching
        // HID collection with the requested access mode.
        devices[device] = ChromecastRemoteReportState(productID: productID)
        onConnectionChanged?(true)
        print(
            String(format: "[CAST-HID] connected VID=0x18d1 PID=0x%04x ", productID) +
            "mode=\(remappingEnabled ? "remap" : "observe")"
        )
    }

    fileprivate func deviceDidRemove(_ device: IOHIDDevice) {
        guard var state = devices.removeValue(forKey: device) else { return }
        nativeMediaGate = ChromecastNativeMediaGate()
        for edge in state.releaseAll() { apply(buttonID: edge.buttonID, isDown: edge.isDown) }
        onConnectionChanged?(!devices.isEmpty)
        print("[CAST-HID] disconnected")
    }

    fileprivate func handleReport(device: IOHIDDevice, reportID: UInt32, data: Data) {
        guard let edges = devices[device]?.handle(reportID: reportID, data: data) else { return }
        for edge in edges {
            if devices[device]?.productID == 0x9451,
               ["0C", "0D", "08"].contains(edge.buttonID) {
                // Without the existing event tap, leave native media keys
                // alone rather than sending a duplicate/custom action.
                guard remappingEnabled, nativeMediaFilterAvailable() else { continue }
                nativeMediaGate.arm(buttonID: edge.buttonID, isDown: edge.isDown,
                                    now: ProcessInfo.processInfo.systemUptime)
            }
            apply(buttonID: edge.buttonID, isDown: edge.isDown)
        }
    }

    func shouldSuppressNativeMedia(type: CGEventType, event: CGEvent) -> Bool {
        guard remappingEnabled, type.rawValue == 14,
              event.getIntegerValueField(.eventSourceUserData) != Key.syntheticMarker,
              let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8
        else { return false }
        let suppressed = nativeMediaGate.shouldSuppress(
            key: (nsEvent.data1 >> 16) & 0xFFFF, isRepeat: nsEvent.data1 & 1 != 0,
            now: ProcessInfo.processInfo.systemUptime
        )
        if suppressed { print("[CAST-HID] suppressed native media data1=\(nsEvent.data1)") }
        return suppressed
    }

    private func releaseAllButtons() {
        nativeMediaGate = ChromecastNativeMediaGate()
        for device in Array(devices.keys) {
            guard let edges = devices[device]?.releaseAll() else { continue }
            for edge in edges { apply(buttonID: edge.buttonID, isDown: edge.isDown) }
        }
    }

    private func apply(buttonID: String, isDown: Bool) {
        guard remappingEnabled,
              let button = RemoteProfiles.chromecastButtons.first(
                where: { $0.id == buttonID }
              )
        else { return }
        let store = RemoteMappingStore.shared
        store.post(button: button, remote: .chromecast, isDown: isDown)
        print(
            "[CAST-MAP] \(button.title) " +
            "\(isDown ? "DOWN" : "UP") -> " +
            store.targetTitle(for: button, remote: .chromecast)
        )
    }
}
