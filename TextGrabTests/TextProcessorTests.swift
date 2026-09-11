import XCTest
@testable import TextGrab

final class TextProcessorTests: XCTestCase {
    private let processor = DefaultTextProcessor()

    func testNormalModeOrdersLinesTopToBottomAndWordsLeftToRight() {
        let observations = [
            OCRObservation(text: "world", confidence: 1, boundingBox: CGRect(x: 0.4, y: 0.75, width: 0.2, height: 0.05)),
            OCRObservation(text: "Hello", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.75, width: 0.2, height: 0.05)),
            OCRObservation(text: "second", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.45, width: 0.3, height: 0.05))
        ]

        XCTAssertEqual(processor.process(observations: observations, mode: .normal), "Hello world\nsecond")
    }

    func testTableModeFormatsMarkdownTable() {
        let observations = [
            OCRObservation(text: "B", confidence: 1, boundingBox: CGRect(x: 0.5, y: 0.8, width: 0.1, height: 0.05)),
            OCRObservation(text: "A", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.1, height: 0.05))
        ]

        XCTAssertEqual(processor.process(observations: observations, mode: .table), "| A | B |\n| --- | --- |")
    }

    func testTableModeNormalizesPipeDelimitedRows() {
        let observations = [
            OCRObservation(text: "| First Name | Last Name |", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.05)),
            OCRObservation(text: "| --- | --- |", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.05)),
            OCRObservation(text: "| Fareed | Awad |", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.8, height: 0.05))
        ]

        XCTAssertEqual(processor.process(observations: observations, mode: .table), "| First Name | Last Name |\n| ---------- | --------- |\n| Fareed     | Awad      |")
    }

    func testTableModeMergesWrappedCellRows() {
        let observations = [
            OCRObservation(text: "| Fareed | Awad | Marketing | Jane Doe, Vice- |", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.05)),
            OCRObservation(text: "| President | | | |", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.05))
        ]

        XCTAssertEqual(processor.process(observations: observations, mode: .table), "| Fareed | Awad | Marketing | Jane Doe, Vice-President |\n| ------ | ---- | ---------- | ------------------------ |")
    }

    func testCodeModeCleansPunctuationSpacing() {
        let codeProcessor = CodeTextProcessor()
        let observations = [
            OCRObservation(text: "import", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.1, height: 0.05)),
            OCRObservation(text: "{", confidence: 1, boundingBox: CGRect(x: 0.2, y: 0.8, width: 0.03, height: 0.05)),
            OCRObservation(text: "SignJWT", confidence: 1, boundingBox: CGRect(x: 0.25, y: 0.8, width: 0.15, height: 0.05)),
            OCRObservation(text: ",", confidence: 1, boundingBox: CGRect(x: 0.4, y: 0.8, width: 0.02, height: 0.05)),
            OCRObservation(text: "jwtVerify", confidence: 1, boundingBox: CGRect(x: 0.43, y: 0.8, width: 0.15, height: 0.05)),
            OCRObservation(text: "}", confidence: 1, boundingBox: CGRect(x: 0.58, y: 0.8, width: 0.03, height: 0.05)),
            OCRObservation(text: ";", confidence: 1, boundingBox: CGRect(x: 0.61, y: 0.8, width: 0.02, height: 0.05))
        ]

        XCTAssertEqual(codeProcessor.process(observations: observations), "import { SignJWT, jwtVerify };")
    }

    func testEmptyObservationsProduceEmptyText() {
        XCTAssertEqual(processor.process(observations: [], mode: .normal), "")
    }
}
