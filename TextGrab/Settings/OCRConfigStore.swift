import Foundation
import Vision
import Combine

final class OCRConfigStore: ObservableObject {
    static let defaultRecognitionLevel = OCRConfiguration.RecognitionLevel.accurate
    static let defaultExtractionMode = OCRMode.normal
    static let defaultLanguages = ["en-US"]

    @Published var recognitionLevel: OCRConfiguration.RecognitionLevel = defaultRecognitionLevel
    @Published var extractionMode: OCRMode = defaultExtractionMode
    @Published var languages: [String] = defaultLanguages
    @Published var usesLanguageCorrection: Bool = false
    @Published var appleIntelligenceCorrection: Bool = false

    static let defaultsKey = "OCRConfigStore"

    private enum CodingKeys: String, CodingKey {
        case recognitionLevel
        case extractionMode
        case languages
        case usesLanguageCorrection
        case appleIntelligenceCorrection
    }

    init() {}

    init(from defaults: UserDefaults) {
        self.recognitionLevel = OCRConfiguration.RecognitionLevel(rawValue: defaults.string(forKey: "recognitionLevel") ?? "") ?? Self.defaultRecognitionLevel
        self.extractionMode = OCRMode(rawValue: defaults.string(forKey: "extractionMode") ?? "") ?? Self.defaultExtractionMode
        self.languages = defaults.stringArray(forKey: "languages")?.filter { !$0.isEmpty } ?? Self.defaultLanguages
        self.usesLanguageCorrection = defaults.object(forKey: "usesLanguageCorrection") as? Bool ?? true
        self.appleIntelligenceCorrection = defaults.object(forKey: "appleIntelligenceCorrection") as? Bool ?? false
    }

    func save(to defaults: UserDefaults) {
        defaults.set(recognitionLevel.rawValue, forKey: "recognitionLevel")
        defaults.set(extractionMode.rawValue, forKey: "extractionMode")
        defaults.set(languages, forKey: "languages")
        defaults.set(usesLanguageCorrection, forKey: "usesLanguageCorrection")
        defaults.set(appleIntelligenceCorrection, forKey: "appleIntelligenceCorrection")
    }

    func reset() {
        self.recognitionLevel = Self.defaultRecognitionLevel
        self.extractionMode = Self.defaultExtractionMode
        self.languages = Self.defaultLanguages
        self.usesLanguageCorrection = true
        self.appleIntelligenceCorrection = false
    }
}