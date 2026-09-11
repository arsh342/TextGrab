import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: NSObjectProtocol?
    private var settingsRequestObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            let settingsTitles = ["General", "OCR", "Permissions", "Advanced"]
            guard settingsTitles.contains(window.title) else { return }
            window.level = .normal
            window.hidesOnDeactivate = false
            window.collectionBehavior.insert(.moveToActiveSpace)
        }
        settingsRequestObserver = NotificationCenter.default.addObserver(
            forName: .settingsRequested,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let settingsTitles = ["General", "OCR", "Permissions", "Advanced"]
                if let window = NSApp.windows.first(where: { settingsTitles.contains($0.title) }) {
                    window.level = .normal
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }

        // SwiftUI's Settings scene is created after the app launches. Open it
        // through the scene action once the menu-bar app is ready.
        if !UserDefaults.standard.bool(forKey: "hasOpenedInitialSettings.v3") {
            UserDefaults.standard.set(true, forKey: "hasOpenedInitialSettings.v3")
            openInitialSettings(attempt: 0)
        }
    }

    private func openInitialSettings(attempt: Int) {
        guard attempt < 10 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.8 : 0.25)) {
            NSApp.activate(ignoringOtherApps: true)
            let selectors = ["showSettingsWindow:", "showPreferencesWindow:"]
            for selectorName in selectors {
                if NSApp.sendAction(Selector((selectorName)), to: nil, from: nil) {
                    NotificationCenter.default.post(name: .settingsRequested, object: nil)
                    return
                }
            }
            self.openInitialSettings(attempt: attempt + 1)
        }
    }

    deinit {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
        if let settingsRequestObserver {
            NotificationCenter.default.removeObserver(settingsRequestObserver)
        }
    }
}

extension Notification.Name {
    static let triggerCapture = Notification.Name("triggerCapture")
    static let triggerSavedCapture = Notification.Name("triggerSavedCapture")
    static let settingsRequested = Notification.Name("settingsRequested")
}
