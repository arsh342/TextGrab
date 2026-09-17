import Foundation
import CoreGraphics
import Vision

enum OCRMode: String, CaseIterable {
    case normal
    case code
    case table

    var displayName: String {
        switch self {
        case .normal: return String(localized: "Text")
        case .code: return String(localized: "Code")
        case .table: return String(localized: "Table")
        }
    }

    var systemImage: String {
        switch self {
        case .normal: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .table: return "tablecells"
        }
    }
}

struct OCRObservation: Equatable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    
    var center: CGPoint {
        CGPoint(x: boundingBox.midX, y: boundingBox.midY)
    }
}

struct OCRResult: Equatable {
    let text: String
    let observations: [OCRObservation]
    let detectedCodes: [DetectedCode]
}

struct DetectedCode: Equatable {
    let value: String
    let symbology: String
    let boundingBox: CGRect
}

struct OCRConfiguration {
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var languages: [String] = ["en-US"]
    var usesLanguageCorrection: Bool = true
    var mode: OCRMode = .normal
    var customWords: [String] = []
    var minimumTextHeight: Float = 0.0
    
    static let `default` = OCRConfiguration.fast
    static let fast = OCRConfiguration(recognitionLevel: .fast)
    static let accurate = OCRConfiguration(recognitionLevel: .accurate)
}

extension OCRConfiguration {
    func apply(to request: VNRecognizeTextRequest) {
        // Code and table extraction are precision-critical: fast recognition
        // misses isolated cells and digits, so they always use accurate.
        // Text mode uses the configured level (fast by default).
        request.recognitionLevel = mode == .normal ? recognitionLevel : .accurate
        request.recognitionLanguages = languages
        // Language correction is for prose. It can mangle code and rewrite
        // or drop short tabular values, so it only applies to normal mode.
        request.usesLanguageCorrection = mode == .normal ? usesLanguageCorrection : false
        request.customWords = customWords
        request.minimumTextHeight = minimumTextHeight
    }
}
