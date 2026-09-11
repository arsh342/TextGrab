import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import Combine

@MainActor
protocol PermissionsService {
    var hasScreenRecordingPermission: Bool { get }
    var hasAccessibilityPermission: Bool { get }
    func requestScreenRecordingPermission() async -> Bool
    func requestAccessibilityPermission() -> Bool
    func openScreenRecordingSettings()
    func openAccessibilitySettings()
}

@MainActor
final class PermissionsManager: ObservableObject, PermissionsService {
    @Published var hasScreenRecordingPermission: Bool = false
    @Published var hasAccessibilityPermission: Bool = false
    @Published var permissionStatus: PermissionStatus = .unknown
    private var activationObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    
    enum PermissionStatus: Equatable {
        case unknown
        case checking
        case screenRecordingDenied
        case accessibilityDenied
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
        let accessibility = checkAccessibilityPermission()
        hasScreenRecordingPermission = screenRecording
        hasAccessibilityPermission = accessibility

        if !screenRecording {
            permissionStatus = .screenRecordingDenied
        } else if !accessibility {
            permissionStatus = .accessibilityDenied
        } else {
            permissionStatus = .allGranted
        }

        Logger.shared.debug("Permissions - Screen: \(screenRecording), Accessibility: \(accessibility)")
    }
    
    private func checkScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    private func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }
    
    func requestScreenRecordingPermission() async -> Bool {
        Logger.shared.info("Requesting screen recording permission")
        // This registers TextGrab in macOS Screen Recording settings. The
        // system prompt owns the navigation; do not open System Settings here.
        _ = CGRequestScreenCaptureAccess()
        checkPermissions()
        return hasScreenRecordingPermission
    }
    
    func requestAccessibilityPermission() -> Bool {
        Logger.shared.info("Requesting accessibility permission")
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        _ = AXIsProcessTrustedWithOptions(options)
        checkPermissions()
        return hasAccessibilityPermission
    }
    
    func openScreenRecordingSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ].compactMap(URL.init(string:))
        openFirstAvailableSettingsURL(urls)
    }
    
    func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ].compactMap(URL.init(string:))
        openFirstAvailableSettingsURL(urls)
    }

    func relaunchApplication() {
        let applicationURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private func openFirstAvailableSettingsURL(_ urls: [URL]) {
        for url in urls where NSWorkspace.shared.open(url) {
            return
        }
    }
}
