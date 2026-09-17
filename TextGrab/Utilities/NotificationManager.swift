import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    private var isAuthorized = false

    init() {
        Task { await requestAuthorization() }
    }

    func requestAuthorization() async {
        do {
            isAuthorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            Logger.shared.error("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func notifyCopied(characterCount: Int, enabled: Bool) {
        guard enabled, isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "TextGrab"
        content.body = String(localized: "Copied \(characterCount) characters to the clipboard.")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        ) { error in
            if let error {
                Logger.shared.error("Notification delivery failed: \(error.localizedDescription)")
            }
        }
    }

    func notifyUpdateAvailable(version: String, enabled: Bool) {
        guard enabled, isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Update available")
        content.body = String(localized: "TextGrab \(version) is ready. Open TextGrab and check Settings to install it.")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "update-\(version)", content: content, trigger: nil)
        ) { error in
            if let error {
                Logger.shared.error("Update notification failed: \(error.localizedDescription)")
            }
        }
    }
}
