import XCTest
@testable import TextGrab

final class TextGrabPerformanceTests: XCTestCase {
    func testLargeDisplayTextOrderingPerformance() {
        let observations = (0..<3_000).map { index in
            OCRObservation(
                text: "word\(index)",
                confidence: 0.99,
                boundingBox: CGRect(
                    x: CGFloat(index % 30) / 30,
                    y: 0.99 - CGFloat(index / 30) / 100,
                    width: 0.02,
                    height: 0.008
                )
            )
        }
        let processor = DefaultTextProcessor()

        measure {
            _ = processor.process(observations: observations, mode: .normal)
        }
    }
}
