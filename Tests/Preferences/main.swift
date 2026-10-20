import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(".local/tests/preferences-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: root) }
let prefs = AppPreferences(directory: root)
func check(_ condition: Bool, _ message: String) {
    guard condition else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    print("PASS: \(message)")
}
prefs.register(defaults: ["toggle": false, "key": "option"])
check(prefs.string(forKey: "key") == "option", "development preferences inherit registered defaults")
prefs.set(true, forKey: "toggle")
prefs.set(Data([1, 2, 3]), forKey: "mapping")
let loaded = AppPreferences(directory: root)
check(loaded.bool(forKey: "toggle"), "development boolean preferences persist within the workspace")
check(loaded.data(forKey: "mapping") == Data([1, 2, 3]), "development binary mappings round-trip")
prefs.set("function", forKey: "key")
prefs.removeObject(forKey: "key")
check(prefs.string(forKey: "key") == "option", "removing an override restores its registered default")
