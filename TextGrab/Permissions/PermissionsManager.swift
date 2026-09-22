import Foundation
import AppKit
import CoreGraphics
import Combine

@MainActor
protocol PermissionsService {
    var hasScreenRecordingPermission: Bool { get }
    func requestScreenRecordingPermission() async -> Bool
    func openScreenRecordingSettings()
}

@MainActor
final class PermissionsManager: ObservableObject, PermissionsService {
    @Published var hasScreenRecordingPermission: Bool = false
    @Published var permissionStatus: PermissionStatus = .unknown
    private var activationObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    enum PermissionStatus: Equatable {
        case unknown
        case checking
        case screenRecordingDenied
        case allGranted
    }

    init() {
        checkPermissions()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        if let wakeObserver {
            NotificationCenter.default.removeObserver(wakeObserver)
        }
    }

    func checkPermissions() {
        permissionStatus = .checking

        let screenRecording = checkScreenRecordingPermission()
        hasScreenRecordingPermission = screenRecording

        if !screenRecording {
            permissionStatus = .screenRecordingDenied
        } else {
            permissionStatus = .allGranted
        }

        Logger.shared.debug("Permissions - Screen: \(screenRecording)")
    }

    private func checkScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecordingPermission() async -> Bool {
        Logger.shared.info("Requesting screen recording permission")
        // This registers TextGrab in macOS Screen Recording settings. The
        // system prompt owns the navigation; do not open System Settings here.
        _ = CGRequestScreenCaptureAccess()
        checkPermissions()
        return hasScreenRecordingPermission
    }

    func openScreenRecordingSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ].compactMap(URL.init(string:))
        openFirstAvailableSettingsURL(urls)
    }

    func relaunchApplication() {
        // `openApplication` would only activate the already-running instance;
        // `open -n` spawns a fresh process so permission changes take effect.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try process.run()
        } catch {
            Logger.shared.error("Relaunch failed: \(error.localizedDescription)")
            return
        }
        // Give the new instance a moment to spawn before quitting this one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    private func openFirstAvailableSettingsURL(_ urls: [URL]) {
        for url in urls where NSWorkspace.shared.open(url) {
            return
        }
    }
}
