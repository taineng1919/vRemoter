import Foundation
func check(_ condition: Bool, _ name: String) {
    guard condition else { fputs("FAIL: \(name)\n", stderr); exit(1) }
    print("PASS: \(name)")
}
let identity = BLERemoteIdentity.googleVoiceRemote
check(identity.matches(pnpID: Data([2,0xD1,0x18,0x50,0x94,0x1B,1])), "9450 remains accepted")
check(identity.matches(pnpID: Data([2,0xD1,0x18,0x51,0x94,5,1])), "actual 9451 PnP response accepted")
check(!identity.matches(pnpID: Data([2,0xD1,0x18,0x52,0x94,5,1])), "unknown Google PID rejected")
check(!identity.matches(pnpID: Data([2,0xD2,0x18,0x51,0x94,5,1])), "other vendor rejected")
check(!identity.matches(pnpID: Data([1,0xD1,0x18,0x51,0x94,5,1])), "Bluetooth SIG vendor namespace rejected")
check(!identity.matches(pnpID: Data([2,0xD1,0x18,0x51,0x94])), "truncated PnP response rejected")
