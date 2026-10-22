import Foundation

typealias Edge = ChromecastRemoteReportState.Edge
var checks = 0
func check(_ value: Bool, _ message: String) {
    guard value else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    checks += 1
    print("PASS: \(message)")
}
func down(_ id: String) -> Edge { Edge(buttonID: id, isDown: true) }
func up(_ id: String) -> Edge { Edge(buttonID: id, isDown: false) }
var remote = ChromecastRemoteReportState(productID: 0x9451)
let captured: [(UInt8, String)] = [(1,"03"),(2,"04"),(3,"05"),(4,"06"),(5,"07"),
                                  (6,"0B"),(7,"0A"),(9,"08"),(10,"0E"),(11,"0F")]
for (selector,id) in captured {
    check(remote.handle(reportID: 2, data: Data([2,selector,0])) == [down(id)]
          && remote.handle(reportID: 2, data: Data([2,0,0])) == [up(id)],
          "captured 9451 report-2 selector \(selector) reuses mapping \(id), DOWN/UP")
}
for (selector,id) in [(UInt8(1),"0C"),(UInt8(2),"0D")] {
    check(remote.handle(reportID: 1, data: Data([1,selector,0,0,0,0,0])) == [down(id)]
          && remote.handle(reportID: 1, data: Data([1,0,0,0,0,0,0])) == [up(id)],
          "captured 9451 volume selector \(selector), DOWN/UP")
}
check(remote.handle(reportID: 2, data: Data([2,1,0])) == [down("03")]
      && remote.handle(reportID: 2, data: Data([2,1,0])).isEmpty, "duplicate report does not repeat DOWN")
check(remote.handle(reportID: 1, data: Data([1,2,0,0,0,0,0])) == [down("0D")]
      && remote.handle(reportID: 2, data: Data([2,0,0])) == [up("03")]
      && remote.releaseAll() == [up("0D")] && remote.releaseAll().isEmpty,
      "report states are independent; cleanup releases remaining keys exactly once")
check(remote.handle(reportID: 2, data: Data([1,0])) == [down("03")]
      && remote.handle(reportID: 2, data: Data([2,0])) == [up("03"),down("04")],
      "prefix-free payload beginning with report ID is not stripped")
check(remote.handle(reportID: 2, data: Data([2])).isEmpty
      && remote.handle(reportID: 7, data: Data([0])).isEmpty
      && remote.releaseAll() == [up("04")], "truncated/unknown reports do not release held keys")
check(remote.handle(reportID: 2, data: Data([2,1,5])) == [down("03"),down("07")]
      && remote.handle(reportID: 2, data: Data([2,5,0])) == [up("03")]
      && remote.releaseAll() == [up("07")], "both array slots are decoded and released independently")
check(remote.handle(reportID: 2, data: Data([2,8,0])).isEmpty
      && remote.handle(reportID: 2, data: Data([2,12,13])).isEmpty,
      "voice and unsampled power/input selectors do not invent mappings")
var legacy = ChromecastRemoteReportState(productID: 0x9450)
check(legacy.handle(reportID: 1, data: Data([1,3,0])) == [down("03")]
      && legacy.handle(reportID: 1, data: Data([1,4,0])) == [up("03"),down("04")]
      && legacy.handle(reportID: 1, data: Data([1,0,0])) == [up("04")]
      && legacy.handle(reportID: 1, data: Data([5])) == [down("05")]
      && legacy.handle(reportID: 2, data: Data([2,1,0])).isEmpty,
      "9450 prefix, replacement, release and prefix-free behavior is retained")
var gate = ChromecastNativeMediaGate()
gate.arm(buttonID: "0D", isDown: true, now: 10)
check(gate.shouldSuppress(key: 1, isRepeat: false, now: 10.01)
      && !gate.shouldSuppress(key: 0, isRepeat: false, now: 10.01)
      && !gate.shouldSuppress(key: 7, isRepeat: false, now: 10.01),
      "native media gate matches only the physical remote's media key")
check(gate.shouldSuppress(key: 1, isRepeat: true, now: 11)
      && !gate.shouldSuppress(key: 1, isRepeat: false, now: 11),
      "held remote suppresses native repeat without swallowing later ordinary media presses")
gate.arm(buttonID: "0D", isDown: false, now: 12)
check(gate.shouldSuppress(key: 1, isRepeat: false, now: 12.01)
      && !gate.shouldSuppress(key: 1, isRepeat: true, now: 12.2),
      "native release is filtered briefly and gate expires")
gate.arm(buttonID: "03", isDown: true, now: 20)
check(!gate.shouldSuppress(key: 0, isRepeat: false, now: 20), "direction keys cannot arm media suppression")
print("\(checks) Chromecast HID checks passed")
