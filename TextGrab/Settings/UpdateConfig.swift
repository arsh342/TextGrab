import Foundation

struct UpdateConfig: Codable {
    static let defaultAutoCheck = true
    static let defaultsKey = "UpdateConfig"

    var checkForUpdatesAutomatically: Bool = defaultAutoCheck
    var lastUpdateCheckDate: Date?

    enum CodingKeys: String, CodingKey {
        case checkForUpdatesAutomatically
        case lastUpdateCheckDate
    }
}

extension UpdateConfig {
    init(from defaults: UserDefaults) {
        self.checkForUpdatesAutomatically = defaults.object(forKey: "checkForUpdatesAutomatically") as? Bool ?? Self.defaultAutoCheck
        self.lastUpdateCheckDate = defaults.object(forKey: "lastUpdateCheckDate") as? Date
    }

    func save(to defaults: UserDefaults) {
        defaults.set(checkForUpdatesAutomatically, forKey: "checkForUpdatesAutomatically")
        if let date = lastUpdateCheckDate {
            defaults.set(date, forKey: "lastUpdateCheckDate")
        } else {
            defaults.removeObject(forKey: "lastUpdateCheckDate")
        }
    }

    mutating func reset() {
        self = Self()
    }
}