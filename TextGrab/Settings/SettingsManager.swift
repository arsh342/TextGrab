import Foundation
import SwiftUI
import Vision
import ServiceManagement
import AppKit
import CoreGraphics
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // Composed config modules
    @Published var shortcuts = ShortcutConfig()
    @Published var ocr = OCRConfigStore()
    @Published var history = HistoryConfig()
    @Published var appearance = AppearanceConfig()
    @Published var updates = UpdateConfig()
    @Published var savedRegion = SavedRegionConfig()

    init() {
        loadAll()
        setupObservers()
    }

    private func loadAll() {
        shortcuts = ShortcutConfig(from: defaults)
        ocr = OCRConfigStore(from: defaults)
        history = HistoryConfig(from: defaults)
        appearance = AppearanceConfig(from: defaults)
        updates = UpdateConfig(from: defaults)
        savedRegion = SavedRegionConfig(from: defaults)

        // Apply launch-at-login on startup
        appearance.applyLaunchAtLogin()
    }

    private func setupObservers() {
        $shortcuts
            .dropFirst()
            .sink { [weak self] config in config.save(to: self?.defaults ?? UserDefaults.standard) }
            .store(in: &cancellables)

        $ocr
            .dropFirst()
            .sink { [weak self] config in config.save(to: self?.defaults ?? UserDefaults.standard) }
            .store(in: &cancellables)

        $history
            .dropFirst()
            .sink { [weak self] config in config.save(to: self?.defaults ?? UserDefaults.standard) }
            .store(in: &cancellables)

        $appearance
            .dropFirst()
            .sink { [weak self] config in
                config.save(to: self?.defaults ?? UserDefaults.standard)
                config.applyLaunchAtLogin()
            }
            .store(in: &cancellables)

        $updates
            .dropFirst()
            .sink { [weak self] config in config.save(to: self?.defaults ?? UserDefaults.standard) }
            .store(in: &cancellables)

        $savedRegion
            .dropFirst()
            .sink { [weak self] config in config.save(to: self?.defaults ?? UserDefaults.standard) }
            .store(in: &cancellables)
    }

    func resetToDefaults() {
        shortcuts.reset()
        ocr.reset()
        history.reset()
        appearance.reset()
        updates.reset()
        savedRegion.reset()

        shortcuts.save(to: defaults)
        ocr.save(to: defaults)
        history.save(to: defaults)
        appearance.save(to: defaults)
        updates.save(to: defaults)
        savedRegion.save(to: defaults)

        appearance.applyLaunchAtLogin()
    }

    // Convenience accessors for backward compatibility
    var shortcut: String {
        get { shortcuts.shortcut }
        set { shortcuts.shortcut = newValue }
    }

    var savedShortcut: String {
        get { shortcuts.savedShortcut }
        set { shortcuts.savedShortcut = newValue }
    }

    var recognitionLevel: OCRConfiguration.RecognitionLevel {
        get { ocr.recognitionLevel }
        set { ocr.recognitionLevel = newValue }
    }

    var extractionMode: OCRMode {
        get { ocr.extractionMode }
        set { ocr.extractionMode = newValue }
    }

    var languages: [String] {
        get { ocr.languages }
        set { ocr.languages = newValue }
    }

    var usesLanguageCorrection: Bool {
        get { ocr.usesLanguageCorrection }
        set { ocr.usesLanguageCorrection = newValue }
    }

    var appleIntelligenceCorrection: Bool {
        get { ocr.appleIntelligenceCorrection }
        set { ocr.appleIntelligenceCorrection = newValue }
    }

    var launchAtLogin: Bool {
        get { appearance.launchAtLogin }
        set { appearance.launchAtLogin = newValue }
    }

    var showNotifications: Bool {
        get { appearance.showNotifications }
        set { appearance.showNotifications = newValue }
    }

    var enableHistory: Bool {
        get { history.enabled }
        set { history.enabled = newValue }
    }

    var maxHistorySize: Int {
        get { history.maxSize }
        set { history.maxSize = newValue }
    }

    var checkForUpdatesAutomatically: Bool {
        get { updates.checkForUpdatesAutomatically }
        set { updates.checkForUpdatesAutomatically = newValue }
    }

    var lastUpdateCheckDate: Date? {
        get { updates.lastUpdateCheckDate }
        set { updates.lastUpdateCheckDate = newValue }
    }

    var savedRegionRect: CGRect? {
        get { savedRegion.region }
        set { savedRegion.region = newValue }
    }

    var savedDisplayID: CGDirectDisplayID? {
        get { savedRegion.displayID }
        set { savedRegion.displayID = newValue }
    }

    var hasSavedRegion: Bool {
        savedRegion.region != nil
    }

    func saveRegion(_ region: CGRect, on screen: NSScreen) {
        savedRegion.region = region
        savedRegion.displayID = screen.displayID
    }

    func clearSavedRegion() {
        savedRegion.clear()
    }
}