import Foundation

/// Translates each model's wire selectors into the existing mapping IDs.
/// 9451 uses two HID arrays, not the 9450 report-1 button codes.
struct ChromecastRemoteReportState {
    struct Edge: Equatable {
        let buttonID: String
        let isDown: Bool
    }

    let productID: Int
    private var buttonsByReport: [UInt32: Set<String>] = [:]

    mutating func handle(reportID: UInt32, data: Data) -> [Edge] {
        guard let buttons = decode(reportID: reportID, data: data) else { return [] }
        let previous = buttonsByReport[reportID] ?? []
        buttonsByReport[reportID] = buttons
        return previous.subtracting(buttons).sorted().map { Edge(buttonID: $0, isDown: false) }
            + buttons.subtracting(previous).sorted().map { Edge(buttonID: $0, isDown: true) }
    }

    mutating func releaseAll() -> [Edge] {
        let buttons = Set(buttonsByReport.values.flatMap { $0 })
        buttonsByReport.removeAll()
        return buttons.sorted().map { Edge(buttonID: $0, isDown: false) }
    }

    private func decode(reportID: UInt32, data: Data) -> Set<String>? {
        if productID == 0x9450 {
            // Keep the existing 9450 report/prefix interpretation.
            guard reportID == 1 else { return nil }
            let payload = data.first == 1 ? Data(data.dropFirst()) : data
            guard let usage = payload.first else { return nil }
            return usage == 0 ? [] : [String(format: "%02X", usage)]
        }
        guard productID == 0x9451 else { return nil }
        if reportID == 1 {
            guard let payload = arrayPayload(data, reportID: 1, count: 6) else { return nil }
            return Set(payload.compactMap { [UInt8(1): "0C", 2: "0D"][$0] })
        }
        guard reportID == 2,
              let payload = arrayPayload(data, reportID: 2, count: 2)
        else { return nil }
        // Descriptor order: Up, Down, Left, Right, Select, Back, Home,
        // Search, Mute, YouTube, Netflix, Power, Input. Search stays ATVV-only.
        let ids: [UInt8: String] = [
            1: "03", 2: "04", 3: "05", 4: "06", 5: "07", 6: "0B",
            7: "0A", 9: "08", 10: "0E", 11: "0F",
        ]
        return Set(payload.compactMap { ids[$0] })
    }

    private func arrayPayload(_ data: Data, reportID: UInt8, count: Int) -> Data? {
        if data.count == count + 1, data.first == reportID { return Data(data.dropFirst()) }
        if data.count == count { return data }
        return nil
    }
}

/// A narrow gate for 9451's native volume/mute events when it cannot be seized.
/// Ordinary key events and unrelated media keys pass. Identical media keys
/// from another device at the same instant cannot be distinguished by CGEventTap.
struct ChromecastNativeMediaGate {
    private var held = Set<Int>()
    private var edgeDeadlines: [Int: TimeInterval] = [:]

    mutating func arm(buttonID: String, isDown: Bool, now: TimeInterval) {
        guard let key = ["0C": 0, "0D": 1, "08": 7][buttonID] else { return }
        if isDown { held.insert(key) } else { held.remove(key) }
        edgeDeadlines[key] = now + 0.15
    }

    func shouldSuppress(key: Int, isRepeat: Bool, now: TimeInterval) -> Bool {
        now <= (edgeDeadlines[key] ?? -.infinity) || (isRepeat && held.contains(key))
    }
}
