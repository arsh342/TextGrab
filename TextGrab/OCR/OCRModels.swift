import Foundation
import CoreGraphics
import Vision

enum OCRMode: String, CaseIterable {
    case normal
    case code
    case table

    var displayName: String {
        switch self {
        case .normal: return "Text"
        case .code: return "Code"
        case .table: return "Table"
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
        request.recognitionLevel = recognitionLevel
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = mode == .code ? false : usesLanguageCorrection
        request.customWords = customWords
        request.minimumTextHeight = minimumTextHeight
    }
}
