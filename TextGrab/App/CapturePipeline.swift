import Foundation
import AppKit
import CoreGraphics

@MainActor
protocol CapturePipeline: AnyObject {
    func capture(region: CGRect?, on screen: NSScreen?) async throws -> String
    func captureSavedRegion() async throws -> String
    func transformLast(_ operation: AITransform) async throws -> String
}

@MainActor
final class DefaultCapturePipeline: CapturePipeline {
    private let screenCapture: ScreenCaptureService
    private let ocrManager: OCRService
    private let clipboardManager: ClipboardService
    private let permissionsManager: PermissionsService
    private let settingsManager: SettingsManager
    private let notificationManager: NotificationManager
    private let selectionController: SelectionController
    private let appState: AppState
    private var appleIntelligence: Any?
    private var lastCapturedText: String?
    private var lastExtractionMode: OCRMode = .normal

    init(
        screenCapture: ScreenCaptureService,
        ocrManager: OCRService,
        clipboardManager: ClipboardService,
        permissionsManager: PermissionsService,
        settingsManager: SettingsManager,
        notificationManager: NotificationManager,
        selectionController: SelectionController,
        appState: AppState
    ) {
        self.screenCapture = screenCapture
        self.ocrManager = ocrManager
        self.clipboardManager = clipboardManager
        self.permissionsManager = permissionsManager
        self.settingsManager = settingsManager
        self.notificationManager = notificationManager
        self.selectionController = selectionController
        self.appState = appState
        if #available(macOS 26.0, *) {
            self.appleIntelligence = AppleIntelligenceService()
        }
    }

    func capture(region: CGRect?, on screen: NSScreen?) async throws -> String {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else {
            throw TextGrabError.captureFailed("No screen available")
        }

        // Check permissions
        if !permissionsManager.hasScreenRecordingPermission {
            let granted = await permissionsManager.requestScreenRecordingPermission()
            if !granted {
                throw TextGrabError.permissionDenied("Enable Screen Recording for TextGrab, then relaunch the app")
            }
        }

        let captureRegion: CGRect
        if let region {
            captureRegion = region
        } else {
            // Interactive selection
            captureRegion = try await selectRegion(on: targetScreen)
        }

        // Save region for repeat capture
        settingsManager.saveRegion(captureRegion, on: targetScreen)

        appState.transition(to: .selecting)

        return try await processCapture(rect: captureRegion, screen: targetScreen, showCopiedStatus: false)
    }

    func captureSavedRegion() async throws -> String {
        let targetScreen: NSScreen

        // Check permissions
        if !permissionsManager.hasScreenRecordingPermission {
            let granted = await permissionsManager.requestScreenRecordingPermission()
            if !granted {
                throw TextGrabError.permissionDenied("Enable Screen Recording for TextGrab, then relaunch the app")
            }
        }

        // Check if we have a saved region for retry
        guard let savedRegion = settingsManager.savedRegionRect,
              let savedDisplayID = settingsManager.savedDisplayID,
              let screen = NSScreen.screens.first(where: { $0.displayID == savedDisplayID }),
              screen.frame.intersection(savedRegion).size == savedRegion.size,
              savedRegion.width > 10,
              savedRegion.height > 10 else {
            throw TextGrabError.captureFailed("Select an area before using the saved-area shortcut")
        }

        // Use saved region for retry
        appState.transition(to: .selecting)

        return try await processCapture(rect: savedRegion, screen: screen, showCopiedStatus: true)
    }

    func transformLast(_ operation: AITransform) async throws -> String {
        guard let text = lastCapturedText else {
            throw TextGrabError.ocrFailed("No previous capture to transform")
        }
        guard #available(macOS 26.0, *), let ai = appleIntelligence as? AppleIntelligenceService else {
            throw TextGrabError.aiFailed("Apple Intelligence is unavailable")
        }

        let mode = lastExtractionMode
        let aiOp: AppleIntelligenceOperation
        switch operation {
        case .correct: aiOp = .correct
        case .summarize: aiOp = .summarize
        case .compact: aiOp = .compact
        }

        let transformed = try await withTimeout(30) {
            try await ai.transform(text, operation: aiOp, mode: mode)
        }

        let output = mode == .code
            ? CodeTextProcessor.removingMarkdownFences(transformed)
            : transformed

        try clipboardManager.copy(output, extractionMode: mode)
        lastCapturedText = output
        lastExtractionMode = mode

        notificationManager.notifyCopied(
            characterCount: output.count,
            enabled: settingsManager.showNotifications
        )

        return output
    }

    private func selectRegion(on screen: NSScreen) async throws -> CGRect {
        try await withCheckedThrowingContinuation { continuation in
            selectionController.startSelection(
                onComplete: { rect, _ in
                    continuation.resume(returning: rect)
                },
                onCancel: {
                    continuation.resume(throwing: TextGrabError.captureFailed("Selection cancelled"))
                }
            )
        }
    }

    private func processCapture(rect: CGRect, screen: NSScreen, showCopiedStatus: Bool) async throws -> String {
        guard let displayID = screen.displayID else {
            throw TextGrabError.captureFailed("Display ID unavailable")
        }

        let displayInfo = DisplayInfo(
            displayID: displayID,
            frame: screen.frame,
            backingScaleFactor: screen.backingScaleFactor,
            localizedName: screen.localizedName
        )

        // Capture
        appState.transition(to: .capturing)
        let image = try await withTimeout(15) { [screenCapture] in
            try await screenCapture.capture(display: displayInfo, region: rect)
        }

        // OCR
        appState.transition(to: .processing)
        var configuration = OCRConfiguration()
        configuration.recognitionLevel = settingsManager.recognitionLevel
        configuration.languages = settingsManager.languages
        configuration.usesLanguageCorrection = settingsManager.usesLanguageCorrection
        configuration.mode = settingsManager.extractionMode
        let ocrConfig = configuration

        let result = try await withTimeout(60) { [ocrManager, image, ocrConfig] in
            try await ocrManager.recognizeText(from: image, configuration: ocrConfig)
        }

        guard result.text.trimmingWhitespaceAndNewlines().isNotEmpty else {
            throw TextGrabError.ocrFailed("No text found in selection")
        }

        var outputText = result.text

        // Apple Intelligence correction (macOS 26+)
        if #available(macOS 26.0, *),
           settingsManager.appleIntelligenceCorrection,
           let ai = appleIntelligence as? AppleIntelligenceService {
            do {
                outputText = try await withTimeout(15) { [settingsManager, ai] in
                    try await ai.transform(
                        result.text,
                        operation: .correct,
                        mode: settingsManager.extractionMode
                    )
                }
            } catch {
                // Silently skip AI correction on failure or timeout
            }
        }

        // Code mode post-processing
        if settingsManager.extractionMode == .code {
            outputText = CodeTextProcessor.removingMarkdownFences(outputText)
        }

        // Copy to clipboard
        try clipboardManager.copy(outputText, extractionMode: settingsManager.extractionMode)

        // Status UI
        if showCopiedStatus {
            selectionController.showStatus("Copied", on: screen)
        }

        // Store for transform
        lastCapturedText = outputText
        lastExtractionMode = settingsManager.extractionMode

        appState.transition(to: .copied(outputText))

        notificationManager.notifyCopied(
            characterCount: outputText.count,
            enabled: settingsManager.showNotifications
        )

        return outputText
    }
}