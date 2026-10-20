import Foundation
enum AppStorage {
    static var inputTriggerKey: InputTriggerKey = .option
    static var functionHoldEnabled = false
    static let recordingsDirectory = URL(fileURLWithPath: ".local/tests/recordings")
    static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
