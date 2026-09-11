import Foundation
import Vision
import CoreGraphics

protocol OCRService {
    func recognizeText(from image: CGImage, configuration: OCRConfiguration) async throws -> OCRResult
}

final class OCRManager: OCRService {
    private let textProcessor: TextProcessor
    
    init(textProcessor: TextProcessor = DefaultTextProcessor()) {
        self.textProcessor = textProcessor
    }
    
    func recognizeText(from image: CGImage, configuration: OCRConfiguration = .default) async throws -> OCRResult {
        let start = Date()
        Logger.shared.debug("Starting OCR recognition on image: \(image.width)x\(image.height)")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [textProcessor] in
                let workingImage = Self.downsampleIfNeeded(image)
                let textRequest = VNRecognizeTextRequest()
                configuration.apply(to: textRequest)

                do {
                    try VNImageRequestHandler(cgImage: workingImage, options: [:]).perform([textRequest])
                    let observations = (textRequest.results as? [VNRecognizedTextObservation] ?? []).compactMap {
                        observation -> OCRObservation? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return OCRObservation(text: candidate.string, confidence: candidate.confidence, boundingBox: observation.boundingBox)
                    }

                    let processor: TextProcessor = configuration.mode == .code
                        ? CodeTextProcessor()
                        : textProcessor
                    let processedText = processor.process(observations: observations, mode: configuration.mode)
                    let combinedText = processedText.trimmingWhitespaceAndNewlines()
                    let elapsedMilliseconds = Int(Date().timeIntervalSince(start) * 1_000)
                    Logger.shared.debug("OCR completed in \(elapsedMilliseconds) ms; observations: \(observations.count)")
                    continuation.resume(returning: OCRResult(text: combinedText, observations: observations, detectedCodes: []))
                } catch {
                    continuation.resume(throwing: TextGrabError.ocrFailed(error.localizedDescription))
                }
            }
        }
    }

    private static func downsampleIfNeeded(_ image: CGImage, maximumDimension: Int = 2400) -> CGImage {
        let largestDimension = max(image.width, image.height)
        guard largestDimension > maximumDimension else { return image }

        let scale = CGFloat(maximumDimension) / CGFloat(largestDimension)
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
              ) else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

}
