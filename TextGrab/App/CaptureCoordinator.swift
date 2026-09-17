import Foundation
import SwiftUI
import AppKit
import CoreGraphics

@MainActor
final class CaptureCoordinator: ObservableObject {
    private let selectionController: SelectionController
    private let screenCapture: ScreenCaptureManager
    private let ocrManager: OCRManager
    private let clipboardManager: ClipboardManager
    private let permissionsManager: PermissionsManager
    private let settingsManager: SettingsManager
    private let appState: AppState
    private let notificationManager: NotificationManager
    private let appleIntelligence: Any?
    private var triggerObserver: NSObjectProtocol?
    private var savedTriggerObserver: NSObjectProtocol?
    
    init(
        selectionController: SelectionController,
        screenCapture: ScreenCaptureManager,
        ocrManager: OCRManager,
        clipboardManager: ClipboardManager,
        permissionsManager: PermissionsManager,
        settingsManager: SettingsManager,
        appState: AppState,
        notificationManager: NotificationManager
    ) {
        self.selectionController = selectionController
        self.screenCapture = screenCapture
        self.ocrManager = ocrManager
        self.clipboardManager = clipboardManager
        self.permissionsManager = permissionsManager
        self.settingsManager = settingsManager
        self.appState = appState
        self.notificationManager = notificationManager
        if #available(macOS 26.0, *) {
            self.appleIntelligence = AppleIntelligenceService()
        } else {
            self.appleIntelligence = nil
        }
        self.triggerObserver = NotificationCenter.default.addObserver(
            forName: .triggerCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.startCapture()
            }
        }
        self.savedTriggerObserver = NotificationCenter.default.addObserver(
            forName: .triggerSavedCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.captureSavedRegion()
            }
        }
    }

    deinit {
        if let triggerObserver {
            NotificationCenter.default.removeObserver(triggerObserver)
        }
        if let savedTriggerObserver {
            NotificationCenter.default.removeObserver(savedTriggerObserver)
        }
    }
    
    func startCapture() {
        guard !appState.isProcessing else { return }
        Logger.shared.info("Starting capture workflow")
        
        guard permissionsManager.hasScreenRecordingPermission else {
            Task { @MainActor in
                let granted = await permissionsManager.requestScreenRecordingPermission()
                if granted {
                    self.startCapture()
                } else {
                    self.appState.transition(to: .error(TextGrabError.permissionDenied("Enable Screen Recording for TextGrab, then relaunch the app")))
                }
            }
            return
        }
        
        appState.transition(to: .selecting)
        
        selectionController.startSelection(
            onComplete: { [weak self] rect, screen in
                Task { @MainActor in
                    if let screen {
                        self?.settingsManager.saveRegion(rect, on: screen)
                    }
                    await self?.processCapture(rect: rect, screen: screen, showCopiedStatus: false)
                }
            },
            onCancel: { [weak self] in
                self?.appState.transition(to: .idle)
            }
        )
    }

    func captureSavedRegion() async {
        guard !appState.isProcessing else { return }
        guard permissionsManager.hasScreenRecordingPermission else {
            let granted = await permissionsManager.requestScreenRecordingPermission()
            if granted {
                await captureSavedRegion()
            } else {
                appState.transition(to: .error(TextGrabError.permissionDenied("Enable Screen Recording for TextGrab, then relaunch the app")))
            }
            return
        }

        guard let region = settingsManager.savedRegion,
              let displayID = settingsManager.savedDisplayID,
              let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else {
            appState.transition(to: .error(TextGrabError.captureFailed("Select an area before using the saved-area shortcut")))
            return
        }

        guard screen.frame.intersection(region).size == region.size,
              region.width > 10,
              region.height > 10 else {
            appState.transition(to: .error(TextGrabError.captureFailed("The saved area is no longer available on this display")))
            return
        }

        await processCapture(rect: region, screen: screen, showCopiedStatus: true)
    }

    /// Repeats the last completed selection without showing the selection overlay.
    func retryLastCapture() async {
        await captureSavedRegion()
    }
    
    private func processCapture(rect: CGRect, screen: NSScreen?, showCopiedStatus: Bool) async {
        Logger.shared.debug("Processing capture for rect: \(rect)")
        
        guard let screen = screen else {
            appState.transition(to: .error(TextGrabError.captureFailed("No screen available")))
            return
        }
        
        appState.transition(to: .capturing)

        do {
            guard let displayID = screen.displayID else {
                appState.transition(to: .error(TextGrabError.captureFailed("Display ID unavailable")))
                return
            }
            let displayInfo = DisplayInfo(
                displayID: displayID,
                frame: screen.frame,
                backingScaleFactor: screen.backingScaleFactor,
                localizedName: screen.localizedName
            )

            let image = try await withTimeout(15) { [screenCapture, displayInfo] in
                try await screenCapture.capture(display: displayInfo, region: rect)
            }

            appState.transition(to: .processing)

            var configuration = OCRConfiguration()
            configuration.recognitionLevel = settingsManager.recognitionLevel.vnLevel
            configuration.languages = settingsManager.languages
            configuration.usesLanguageCorrection = settingsManager.usesLanguageCorrection
            configuration.mode = settingsManager.extractionMode
            let ocrConfiguration = configuration

            let result = try await withTimeout(60) { [ocrManager, image, ocrConfiguration] in
                try await ocrManager.recognizeText(from: image, configuration: ocrConfiguration)
            }

            guard result.text.trimmingWhitespaceAndNewlines().isNotEmpty else {
                appState.transition(to: .error(TextGrabError.ocrFailed("No text found in selection")))
                return
            }

            var outputText = result.text
            if #available(macOS 26.0, *),
               settingsManager.appleIntelligenceCorrection,
               let appleIntelligenceService = appleIntelligence as? AppleIntelligenceService {
                do {
                    let extractionMode = settingsManager.extractionMode
                    outputText = try await withTimeout(30) {
                        try await appleIntelligenceService.transform(
                            result.text,
                            operation: .correct,
                            mode: extractionMode
                        )
                    }
                } catch {
                    Logger.shared.error("Apple Intelligence correction skipped: \(error.localizedDescription)")
                }
            }

            if settingsManager.extractionMode == .code {
                outputText = CodeTextProcessor.removingMarkdownFences(outputText)
            }

            try clipboardManager.copy(outputText)
            
            if showCopiedStatus {
                selectionController.showStatus(on: screen)
            }
            appState.transition(to: .copied(outputText))
            notificationManager.notifyCopied(
                characterCount: outputText.count,
                enabled: settingsManager.showNotifications
            )
            
            Logger.shared.info("Capture completed successfully: \(outputText.count) characters")
            
        } catch let error as TextGrabError {
            appState.transition(to: .error(error))
        } catch {
            Logger.shared.error("Capture failed: \(error)")
            appState.transition(to: .error(TextGrabError.captureFailed(error.localizedDescription)))
        }
    }

    func transformLastCapture(_ operation: AppleIntelligenceOperation) async {
        guard !appState.isProcessing, let text = appState.lastCapturedText else { return }
        guard #available(macOS 26.0, *),
              let appleIntelligence = appleIntelligence as? AppleIntelligenceService else {
            appState.transition(to: .error(TextGrabError.aiFailed("Apple Intelligence is unavailable")))
            return
        }

        appState.transition(to: .processing)
        do {
            let extractionMode = settingsManager.extractionMode
            let transformed = try await withTimeout(30) {
                try await appleIntelligence.transform(
                    text,
                    operation: operation,
                    mode: extractionMode
                )
            }
            let output = settingsManager.extractionMode == .code
                ? CodeTextProcessor.removingMarkdownFences(transformed)
                : transformed
            try clipboardManager.copy(output)
            appState.transition(to: .copied(output))
            notificationManager.notifyCopied(
                characterCount: output.count,
                enabled: settingsManager.showNotifications
            )
        } catch let error as AppleIntelligenceError {
            appState.transition(to: .error(TextGrabError.aiFailed(error.localizedDescription)))
        } catch {
            appState.transition(to: .error(TextGrabError.aiFailed(error.localizedDescription)))
        }
    }
}
