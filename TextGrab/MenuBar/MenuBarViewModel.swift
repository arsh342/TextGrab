import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
protocol MenuBarViewModel: ObservableObject {
    var isProcessing: Bool { get }
    var lastCapture: String? { get }
    var lastError: TextGrabError? { get }
    var history: [HistoryItem] { get }
    var currentShortcut: String { get }
    var savedShortcut: String { get }
    var hasSavedRegion: Bool { get }
    var extractionMode: OCRMode { get set }
    var showNotifications: Bool { get }
    var enableHistory: Bool { get }
    var processingText: String { get }
    var isTransforming: Bool { get }
    var transformingOperation: AITransform? { get }
    var maxHistorySize: Int { get }

    func captureAction()
    func retryAction()
    func transformLast(_ operation: AITransform)
    func copyFromHistory(_ item: HistoryItem)
    func copyText(_ text: String)
    func deleteFromHistory(_ item: HistoryItem)
    func clearHistory()
    func speakLastCapture()
    func stopSpeaking()
    var isSpeaking: Bool { get }
}

@MainActor
final class DefaultMenuBarViewModel: MenuBarViewModel {
    private let captureCoordinator: CapturePipeline
    private let appState: AppState
    private let shortcutManager: GlobalShortcutManager
    private let settingsManager: SettingsManager
    private let clipboardManager: ClipboardManager
    private let speechManager: TextToSpeechManager

    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastCapture: String?
    @Published private(set) var lastError: TextGrabError?
    @Published private(set) var history: [HistoryItem] = []
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var processingState: AppState.State = .idle
    @Published private var _extractionMode: OCRMode = .normal
    @Published private(set) var isTransforming: Bool = false
    @Published private(set) var transformingOperation: AITransform? = nil

    var extractionMode: OCRMode {
        get { _extractionMode }
        set {
            _extractionMode = newValue
            settingsManager.extractionMode = newValue
        }
    }

    var maxHistorySize: Int {
        settingsManager.maxHistorySize
    }

    init(
        captureCoordinator: CapturePipeline,
        appState: AppState,
        shortcutManager: GlobalShortcutManager,
        settingsManager: SettingsManager,
        clipboardManager: ClipboardManager,
        speechManager: TextToSpeechManager
    ) {
        self.captureCoordinator = captureCoordinator
        self.appState = appState
        self.shortcutManager = shortcutManager
        self.settingsManager = settingsManager
        self.clipboardManager = clipboardManager
        self.speechManager = speechManager

        // Sync published state from dependencies
        isProcessing = appState.isProcessing
        lastCapture = appState.lastCapturedText
        lastError = appState.lastError
        history = clipboardManager.history
        isSpeaking = speechManager.isSpeaking
        processingState = appState.currentState
        _extractionMode = settingsManager.extractionMode

        // Observe changes
        observeChanges()
    }

    private func observeChanges() {
        // AppState
        appState.$isProcessing.assign(to: &$isProcessing)
        appState.$lastCapturedText.assign(to: &$lastCapture)
        appState.$lastError.assign(to: &$lastError)
        appState.$currentState.assign(to: &$processingState)

        // ClipboardManager
        clipboardManager.$history.assign(to: &$history)

        // SpeechManager
        speechManager.$isSpeaking.assign(to: &$isSpeaking)

        // Settings - observe extraction mode changes
        settingsManager.ocr.$extractionMode
            .assign(to: &$_extractionMode)
    }

    var processingText: String {
        switch processingState {
        case .selecting: return String(localized: "Select area...")
        case .capturing: return String(localized: "Capturing screen...")
        case .processing: return String(localized: "Recognizing text...")
        default: return String(localized: "Processing...")
        }
    }

    var currentShortcut: String { shortcutManager.currentShortcut }
    var savedShortcut: String { shortcutManager.currentSavedShortcut }
    var hasSavedRegion: Bool { settingsManager.hasSavedRegion }
    var showNotifications: Bool { settingsManager.showNotifications }
    var enableHistory: Bool { settingsManager.enableHistory }

    func captureAction() {
        Task { @MainActor in
            do {
                _ = try await captureCoordinator.capture(region: nil, on: nil)
            } catch {
                appState.transition(to: .error(error as? TextGrabError ?? TextGrabError.captureFailed(error.localizedDescription)))
            }
        }
    }

    func retryAction() {
        Task { @MainActor in
            do {
                _ = try await captureCoordinator.captureSavedRegion()
            } catch {
                appState.transition(to: .error(error as? TextGrabError ?? TextGrabError.captureFailed(error.localizedDescription)))
            }
        }
    }

    func transformLast(_ operation: AITransform) {
        isTransforming = true
        transformingOperation = operation
        Task { @MainActor in
            do {
                _ = try await captureCoordinator.transformLast(operation)
            } catch {
                appState.transition(to: .error(error as? TextGrabError ?? TextGrabError.aiFailed(error.localizedDescription)))
            }
            isTransforming = false
            transformingOperation = nil
        }
    }

    func copyFromHistory(_ item: HistoryItem) {
        do {
            try clipboardManager.copy(item.text, extractionMode: .normal)
        } catch {
            appState.transition(to: .error(error as? TextGrabError ?? TextGrabError.clipboardFailed(error.localizedDescription)))
        }
    }

    func copyText(_ text: String) {
        do {
            try clipboardManager.copy(text, extractionMode: .normal)
        } catch {
            appState.transition(to: .error(error as? TextGrabError ?? TextGrabError.clipboardFailed(error.localizedDescription)))
        }
    }

    func deleteFromHistory(_ item: HistoryItem) {
        clipboardManager.removeFromHistory(item)
    }

    func clearHistory() {
        clipboardManager.clearHistory()
    }

    func speakLastCapture() {
        guard let text = lastCapture, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        speechManager.speak(text)
    }

    func stopSpeaking() {
        speechManager.stop()
    }
}

extension MenuBarViewModel {
    var isTransforming: Bool { false }
    var transformingOperation: AITransform? { nil }
}