import Foundation
import IOKit

/// Identifies the voice peripheral without opening or seizing its HID interface.
struct BLERemoteIdentity {
    let vendorID: Int
    let productIDs: Set<Int>

    static let googleVoiceRemote = BLERemoteIdentity(
        vendorID: 0x18D1,
        productIDs: [0x9450, 0x9451]
    )

    func matches(pnpID: Data) -> Bool {
        let bytes = [UInt8](pnpID)
        guard bytes.count >= 7, bytes[0] == 0x02 else { return false }
        let vendor = Int(bytes[1]) | Int(bytes[2]) << 8
        let product = Int(bytes[3]) | Int(bytes[4]) << 8
        return vendor == vendorID && productIDs.contains(product)
    }

    /// PhysicalDeviceUniqueID is the CoreBluetooth UUID on macOS BLE HID
    /// devices. Registry properties remain readable without Input Monitoring.
    func matchingHIDPeripheralIDs() -> Set<UUID> {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator
        ) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var identifiers = Set<UUID>()
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(
                    service, key as CFString, kCFAllocatorDefault, 0
                )?.takeRetainedValue()
            }
            guard (property("VendorID") as? NSNumber)?.intValue == vendorID,
                  let product = (property("ProductID") as? NSNumber)?.intValue,
                  productIDs.contains(product),
                  let value = property("PhysicalDeviceUniqueID") as? String,
                  let identifier = UUID(uuidString: value) else { continue }
            identifiers.insert(identifier)
        }
        return identifiers
    }
}
