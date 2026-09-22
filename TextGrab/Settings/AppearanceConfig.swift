import Foundation
import ServiceManagement

struct AppearanceConfig: Codable {
    static let defaultLaunchAtLogin = false
    static let defaultShowNotifications = true

    var launchAtLogin: Bool = defaultLaunchAtLogin
    var showNotifications: Bool = defaultShowNotifications

    static let defaultsKey = "AppearanceConfig"

    enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case showNotifications
    }
}

extension AppearanceConfig {
    init(from defaults: UserDefaults) {
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.showNotifications = defaults.object(forKey: "showNotifications") as? Bool ?? Self.defaultShowNotifications
    }

    func save(to defaults: UserDefaults) {
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(showNotifications, forKey: "showNotifications")
    }

    mutating func reset() {
        self = Self()
    }
}

// Side-effect handling for launchAtLogin
extension AppearanceConfig {
    func applyLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.shared.error("Failed to update launch-at-login: \(error.localizedDescription)")
        }
    }
}