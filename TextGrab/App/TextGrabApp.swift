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
    @StateObject private var updateManager: UpdateManager
    private let selectionController: SelectionController
    private let screenCapture: ScreenCaptureManager
    private let ocrManager: OCRManager
    private let pipeline: DefaultCapturePipeline
    @StateObject private var captureCoordinator: CaptureCoordinator
    @StateObject private var menuBarViewModel: DefaultMenuBarViewModel

    init() {
        let appState = AppState()
        let permissionsManager = PermissionsManager()
        let shortcutManager = GlobalShortcutManager()
        let settingsManager = SettingsManager.shared
        let clipboardManager = ClipboardManager(settings: settingsManager)
        let speechManager = TextToSpeechManager()
        let notificationManager = NotificationManager()
        let updateManager = UpdateManager(settingsManager: settingsManager)
        let screenCapture = ScreenCaptureManager()
        let ocrManager = OCRManager()

        do {
            try shortcutManager.register()
        } catch let error as TextGrabError {
            appState.transition(to: .error(error))
        } catch {
            appState.transition(to: .error(TextGrabError.shortcutRegistrationFailed(error.localizedDescription)))
        }

        // Daily update check against GitHub Releases (opt-in, rate-limited).
        Task { @MainActor in
            if let update = await updateManager.checkForUpdates(automatically: true) {
                notificationManager.notifyUpdateAvailable(
                    version: update.version,
                    enabled: settingsManager.showNotifications
                )
            }
        }

        // Create selection controller
        let selectionController = DefaultSelectionController.makeDefault()

        let pipeline = DefaultCapturePipeline(
            screenCapture: screenCapture,
            ocrManager: ocrManager,
            clipboardManager: clipboardManager,
            permissionsManager: permissionsManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager,
            selectionController: selectionController,
            appState: appState
        )

        let captureCoordinator = CaptureCoordinator(pipeline: pipeline)

        let menuBarViewModel = DefaultMenuBarViewModel(
            captureCoordinator: pipeline,
            appState: appState,
            shortcutManager: shortcutManager,
            settingsManager: settingsManager,
            clipboardManager: clipboardManager,
            speechManager: speechManager
        )

        self._appState = StateObject(wrappedValue: appState)
        self._permissionsManager = StateObject(wrappedValue: permissionsManager)
        self._shortcutManager = StateObject(wrappedValue: shortcutManager)
        self._settingsManager = StateObject(wrappedValue: settingsManager)
        self._clipboardManager = StateObject(wrappedValue: clipboardManager)
        self._speechManager = StateObject(wrappedValue: speechManager)
        self._notificationManager = StateObject(wrappedValue: notificationManager)
        self._updateManager = StateObject(wrappedValue: updateManager)
        self.selectionController = selectionController
        self.screenCapture = screenCapture
        self.ocrManager = ocrManager
        self.pipeline = pipeline
        self._captureCoordinator = StateObject(wrappedValue: captureCoordinator)
        self._menuBarViewModel = StateObject(wrappedValue: menuBarViewModel)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: menuBarViewModel)
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
                .environmentObject(updateManager)
                .environmentObject(clipboardManager)
        }
    }
}
