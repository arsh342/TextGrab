import SwiftUI
import AppKit

@main
struct TextGrabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState
    @StateObject private var permissionsManager: PermissionsManager
    @StateObject private var shortcutManager: GlobalShortcutManager
    @StateObject private var settingsManager: SettingsManager
    @StateObject private var clipboardManager: ClipboardManager
    @StateObject private var speechManager: TextToSpeechManager
    @StateObject private var notificationManager: NotificationManager
    private let selectionController: SelectionController
    private let screenCapture: ScreenCaptureManager
    private let ocrManager: OCRManager
    @StateObject private var captureCoordinator: CaptureCoordinator
    
    init() {
        let appState = AppState()
        let permissionsManager = PermissionsManager()
        let shortcutManager = GlobalShortcutManager()
        let settingsManager = SettingsManager()
        let clipboardManager = ClipboardManager(settings: settingsManager)
        let speechManager = TextToSpeechManager()
        let notificationManager = NotificationManager()
        let selectionController = SelectionController()
        let screenCapture = ScreenCaptureManager()
        let ocrManager = OCRManager()

        do {
            try shortcutManager.register()
        } catch let error as TextGrabError {
            appState.transition(to: .error(error))
        } catch {
            appState.transition(to: .error(TextGrabError.shortcutRegistrationFailed(error.localizedDescription)))
        }
        
        let captureCoordinator = CaptureCoordinator(
            selectionController: selectionController,
            screenCapture: screenCapture,
            ocrManager: ocrManager,
            clipboardManager: clipboardManager,
            permissionsManager: permissionsManager,
            settingsManager: settingsManager,
            appState: appState,
            notificationManager: notificationManager
        )
        
        self._appState = StateObject(wrappedValue: appState)
        self._permissionsManager = StateObject(wrappedValue: permissionsManager)
        self._shortcutManager = StateObject(wrappedValue: shortcutManager)
        self._settingsManager = StateObject(wrappedValue: settingsManager)
        self._clipboardManager = StateObject(wrappedValue: clipboardManager)
        self._speechManager = StateObject(wrappedValue: speechManager)
        self._notificationManager = StateObject(wrappedValue: notificationManager)
        self.selectionController = selectionController
        self.screenCapture = screenCapture
        self.ocrManager = ocrManager
        self._captureCoordinator = StateObject(wrappedValue: captureCoordinator)
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(permissionsManager)
                .environmentObject(shortcutManager)
                .environmentObject(settingsManager)
                .environmentObject(clipboardManager)
                .environmentObject(speechManager)
                .environmentObject(notificationManager)
                .environmentObject(captureCoordinator)
        } label: {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 16, weight: .medium))
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
                .environmentObject(shortcutManager)
                .environmentObject(permissionsManager)
        }
    }
}
