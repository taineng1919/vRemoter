import Foundation

/// Normal launches forward to the existing defaults domain. A development
/// profile keeps all preferences in its workspace without touching that domain.
final class AppPreferences {
    private let file: URL?
    private var values: [String: Any] = [:]
    private var registered: [String: Any] = [:]

    init(directory: URL? = nil) {
        file = directory?.appendingPathComponent("Preferences.plist")
        if let file, let data = try? Data(contentsOf: file),
           let stored = try? PropertyListSerialization.propertyList(
               from: data, format: nil
           ) as? [String: Any] {
            values = stored
        }
    }

    func register(defaults: [String: Any]) {
        if file == nil { UserDefaults.standard.register(defaults: defaults) }
        else { registered.merge(defaults) { _, new in new } }
    }

    func object(forKey key: String) -> Any? {
        if file == nil { return UserDefaults.standard.object(forKey: key) }
        return values[key] ?? registered[key]
    }

    func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? NSNumber)?.boolValue ?? false
    }
    func string(forKey key: String) -> String? { object(forKey: key) as? String }
    func data(forKey key: String) -> Data? { object(forKey: key) as? Data }

    func set(_ value: Any?, forKey key: String) {
        guard let file else { UserDefaults.standard.set(value, forKey: key); return }
        values[key] = value
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: values, format: .binary, options: 0
            )
            try data.write(to: file, options: .atomic)
        } catch {
            print("[PREFERENCES] Cannot save development profile: \(error)")
        }
    }

    func removeObject(forKey key: String) { set(nil, forKey: key) }
}
