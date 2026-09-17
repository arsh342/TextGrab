import Foundation
import Vision
import CoreGraphics
import CoreImage

protocol OCRService {
    func recognizeText(from image: CGImage, configuration: OCRConfiguration) async throws -> OCRResult
}

final class OCRManager: OCRService {
    private let textProcessor: TextProcessor
    private static let coreImageContext = CIContext()

    init(textProcessor: TextProcessor = DefaultTextProcessor()) {
        self.textProcessor = textProcessor
    }

    func recognizeText(from image: CGImage, configuration: OCRConfiguration = .default) async throws -> OCRResult {
        let start = Date()
        Logger.shared.debug("Starting OCR recognition on image: \(image.width)x\(image.height)")

        var result = try await performRecognition(from: image, configuration: configuration)

        // Code and table are always recognized at accurate level (forced in
        // OCRConfiguration.apply), so the accurate retry only helps when the
        // primary pass ran fast (text mode).
        let effectiveLevel: VNRequestTextRecognitionLevel = configuration.mode == .normal
            ? configuration.recognitionLevel
            : .accurate

        if result.text.isEmpty, effectiveLevel != .accurate {
            // Low-contrast captures (white text on dark backgrounds) can come
            // back empty. Retry at accurate level with language correction off.
            var retryConfiguration = configuration
            retryConfiguration.recognitionLevel = .accurate
            retryConfiguration.usesLanguageCorrection = false
            Logger.shared.debug("OCR empty; retrying with accurate recognition")
            result = try await performRecognition(from: image, configuration: retryConfiguration)
        }

        if result.text.isEmpty {
            // Last resort: invert the image so light-on-dark text becomes
            // dark-on-light, which Vision recognizes reliably.
            guard let inverted = Self.invertedImage(from: image) else { return result }
            var retryConfiguration = configuration
            retryConfiguration.recognitionLevel = .accurate
            Logger.shared.debug("OCR empty; retrying with inverted image")
            result = try await performRecognition(from: inverted, configuration: retryConfiguration)
        }

        Logger.shared.debug("OCR completed in \(Int(Date().timeIntervalSince(start) * 1_000)) ms")
        return result
    }

    private func performRecognition(from image: CGImage, configuration: OCRConfiguration) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [textProcessor] in
                let workingImage = Self.downsampleIfNeeded(image)
                let textRequest = VNRecognizeTextRequest()
                configuration.apply(to: textRequest)

                do {
                    try VNImageRequestHandler(cgImage: workingImage, options: [:]).perform([textRequest])
                    let observations = (textRequest.results ?? []).compactMap {
                        observation -> OCRObservation? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return OCRObservation(text: candidate.string, confidence: candidate.confidence, boundingBox: observation.boundingBox)
                    }

                    let processor: TextProcessor = configuration.mode == .code
                        ? CodeTextProcessor()
                        : textProcessor
                    let processedText = processor.process(observations: observations, mode: configuration.mode)
                    let combinedText = processedText.trimmingWhitespaceAndNewlines()
                    continuation.resume(returning: OCRResult(text: combinedText, observations: observations, detectedCodes: []))
                } catch {
                    continuation.resume(throwing: TextGrabError.ocrFailed(error.localizedDescription))
                }
            }
        }
    }

    private static func invertedImage(from image: CGImage) -> CGImage? {
        guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let cgImage = coreImageContext.createCGImage(output, from: output.extent) else { return nil }
        return cgImage
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
