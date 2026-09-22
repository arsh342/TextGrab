import Foundation

struct HistoryConfig: Codable {
    static let defaultEnabled = false
    static let defaultMaxSize = 20

    var enabled: Bool = defaultEnabled
    var maxSize: Int = defaultMaxSize

    static let defaultsKey = "HistoryConfig"
    private static let migrationKey = "HistoryConfig.migratedToV2"

    enum CodingKeys: String, CodingKey {
        case enabled
        case maxSize
    }
}

extension HistoryConfig {
    init(from defaults: UserDefaults) {
        // Migration: reset history size to 20 for existing users who haven't migrated
        let hasMigrated = defaults.bool(forKey: Self.migrationKey)
        if !hasMigrated {
            self.enabled = defaults.object(forKey: "enableHistory") as? Bool ?? Self.defaultEnabled
            self.maxSize = Self.defaultMaxSize // Force reset to 20
            defaults.set(true, forKey: Self.migrationKey)
        } else {
            self.enabled = defaults.object(forKey: "enableHistory") as? Bool ?? Self.defaultEnabled
            self.maxSize = min(max(defaults.object(forKey: "maxHistorySize") as? Int ?? Self.defaultMaxSize, 1), 200)
        }
    }

    func save(to defaults: UserDefaults) {
        defaults.set(enabled, forKey: "enableHistory")
        defaults.set(maxSize, forKey: "maxHistorySize")
    }

    mutating func reset() {
        self = Self()
    }
}