import Foundation
import SwiftUI
import Vision
import ServiceManagement
import AppKit
import CoreGraphics

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let shortcut = "shortcut"
        static let savedRegion = "savedRegion"
        static let savedDisplayID = "savedDisplayID"
        static let recognitionLevel = "recognitionLevel"
        static let extractionMode = "extractionMode"
        static let languages = "languages"
        static let usesLanguageCorrection = "usesLanguageCorrection"
        static let appleIntelligenceCorrection = "appleIntelligenceCorrection"
        static let launchAtLogin = "launchAtLogin"
        static let showNotifications = "showNotifications"
        static let enableHistory = "enableHistory"
        static let maxHistorySize = "maxHistorySize"
        static let checkForUpdatesAutomatically = "checkForUpdatesAutomatically"
        static let lastUpdateCheckDate = "lastUpdateCheckDate"
    }
    
    @Published var shortcut: String = "⌘⇧2" {
        didSet { defaults.set(shortcut, forKey: Keys.shortcut) }
    }
    
    @Published var recognitionLevel: OCRConfiguration.RecognitionLevel = .fast {
        didSet { defaults.set(recognitionLevel.rawValue, forKey: Keys.recognitionLevel) }
    }

    @Published var extractionMode: OCRMode = .normal {
        didSet { defaults.set(extractionMode.rawValue, forKey: Keys.extractionMode) }
    }
    
    @Published var languages: [String] = ["en-US"] {
        didSet { defaults.set(languages, forKey: Keys.languages) }
    }
    
    @Published var usesLanguageCorrection: Bool = true {
        didSet { defaults.set(usesLanguageCorrection, forKey: Keys.usesLanguageCorrection) }
    }

    @Published var appleIntelligenceCorrection: Bool = false {
        didSet { defaults.set(appleIntelligenceCorrection, forKey: Keys.appleIntelligenceCorrection) }
    }
    
    @Published var launchAtLogin: Bool = false {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin); updateLaunchAtLogin() }
    }
    
    @Published var showNotifications: Bool = true {
        didSet { defaults.set(showNotifications, forKey: Keys.showNotifications) }
    }
    
    @Published var enableHistory: Bool = true {
        didSet { defaults.set(enableHistory, forKey: Keys.enableHistory) }
    }
    
    @Published var maxHistorySize: Int = 50 {
        didSet { defaults.set(maxHistorySize, forKey: Keys.maxHistorySize) }
    }

    @Published var checkForUpdatesAutomatically: Bool = true {
        didSet { defaults.set(checkForUpdatesAutomatically, forKey: Keys.checkForUpdatesAutomatically) }
    }

    var lastUpdateCheckDate: Date? {
        get { defaults.object(forKey: Keys.lastUpdateCheckDate) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.lastUpdateCheckDate)
            } else {
                defaults.removeObject(forKey: Keys.lastUpdateCheckDate)
            }
        }
    }

    @Published private(set) var savedRegion: CGRect?
    @Published private(set) var savedDisplayID: CGDirectDisplayID?
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        shortcut = defaults.string(forKey: Keys.shortcut) ?? "⌘⇧2"
        recognitionLevel = OCRConfiguration.RecognitionLevel(rawValue: defaults.string(forKey: Keys.recognitionLevel) ?? "") ?? .fast
        // Migrate the removed Auto mode to the fast, predictable Text mode.
        extractionMode = OCRMode(rawValue: defaults.string(forKey: Keys.extractionMode) ?? "") ?? .normal
        languages = defaults.stringArray(forKey: Keys.languages)?.filter { !$0.isEmpty } ?? ["en-US"]
        usesLanguageCorrection = defaults.object(forKey: Keys.usesLanguageCorrection) as? Bool ?? true
        appleIntelligenceCorrection = defaults.object(forKey: Keys.appleIntelligenceCorrection) as? Bool ?? false
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showNotifications = defaults.object(forKey: Keys.showNotifications) as? Bool ?? true
        enableHistory = defaults.object(forKey: Keys.enableHistory) as? Bool ?? true
        maxHistorySize = min(max(defaults.object(forKey: Keys.maxHistorySize) as? Int ?? 50, 1), 500)
        checkForUpdatesAutomatically = defaults.object(forKey: Keys.checkForUpdatesAutomatically) as? Bool ?? true
        if let value = defaults.string(forKey: Keys.savedRegion) {
            savedRegion = NSRectFromString(value)
        }
        if defaults.object(forKey: Keys.savedDisplayID) != nil {
            savedDisplayID = CGDirectDisplayID(defaults.integer(forKey: Keys.savedDisplayID))
        }
    }
    
    private func updateLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.shared.error("Failed to update launch-at-login: \(error.localizedDescription)")
        }
    }
    
    func resetToDefaults() {
        shortcut = "⌘⇧2"
        recognitionLevel = .fast
        extractionMode = .normal
        languages = ["en-US"]
        usesLanguageCorrection = true
        appleIntelligenceCorrection = false
        launchAtLogin = false
        showNotifications = true
        enableHistory = true
        maxHistorySize = 50
        checkForUpdatesAutomatically = true
        clearSavedRegion()
    }

    func saveRegion(_ region: CGRect, on screen: NSScreen) {
        savedRegion = region
        savedDisplayID = screen.displayID
        defaults.set(NSStringFromRect(region), forKey: Keys.savedRegion)
        if let displayID = screen.displayID {
            defaults.set(Int(displayID), forKey: Keys.savedDisplayID)
        } else {
            defaults.removeObject(forKey: Keys.savedDisplayID)
        }
    }

    func clearSavedRegion() {
        savedRegion = nil
        savedDisplayID = nil
        defaults.removeObject(forKey: Keys.savedRegion)
        defaults.removeObject(forKey: Keys.savedDisplayID)
    }
}

extension OCRConfiguration {
    enum RecognitionLevel: String, CaseIterable {
        case fast = "fast"
        case accurate = "accurate"
        
        var displayName: String {
            switch self {
            case .fast: return String(localized: "Fast")
            case .accurate: return String(localized: "Accurate")
            }
        }
        
        var vnLevel: VNRequestTextRecognitionLevel {
            switch self {
            case .fast: return .fast
            case .accurate: return .accurate
            }
        }
    }
    
    var recognitionLevelEnum: RecognitionLevel {
        get { RecognitionLevel(rawValue: recognitionLevel == .fast ? "fast" : "accurate") ?? .accurate }
        set { recognitionLevel = newValue.vnLevel }
    }
}
