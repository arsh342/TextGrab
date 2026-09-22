import Foundation
import CoreGraphics

struct SavedRegionConfig: Codable {
    var region: CGRect?
    var displayID: CGDirectDisplayID?

    static let defaultsKey = "SavedRegionConfig"

    enum CodingKeys: String, CodingKey {
        case region
        case displayID
    }
}

extension SavedRegionConfig {
    init(from defaults: UserDefaults) {
        if let value = defaults.string(forKey: "savedRegion") {
            self.region = NSRectFromString(value)
        }
        if defaults.object(forKey: "savedDisplayID") != nil {
            self.displayID = CGDirectDisplayID(defaults.integer(forKey: "savedDisplayID"))
        }
    }

    func save(to defaults: UserDefaults) {
        if let region = region {
            defaults.set(NSStringFromRect(region), forKey: "savedRegion")
        } else {
            defaults.removeObject(forKey: "savedRegion")
        }
        if let displayID = displayID {
            defaults.set(Int(displayID), forKey: "savedDisplayID")
        } else {
            defaults.removeObject(forKey: "savedDisplayID")
        }
    }

    mutating func clear() {
        self.region = nil
        self.displayID = nil
    }

    mutating func reset() {
        self = Self()
    }
}