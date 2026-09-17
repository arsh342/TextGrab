import Foundation
import CoreGraphics

protocol TextProcessor: Sendable {
    func process(observations: [OCRObservation], mode: OCRMode) -> String
}

final class DefaultTextProcessor: TextProcessor {
    private let lineGroupingTolerance: CGFloat = 0.5
    
    func process(observations: [OCRObservation], mode: OCRMode = .normal) -> String {
        guard !observations.isEmpty else { return "" }
        
        let lines = groupIntoLines(observations)
        // Vision uses a bottom-left origin, so larger Y values are visually higher.
        let sortedLines = lines.sorted { $0.minY > $1.minY }

        if mode == .code {
            return formatCode(sortedLines)
        }

        if mode == .table {
            return formatTable(sortedLines)
        }

        let linesText = sortedLines.map { line in
            let sortedWords = line.observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            return sortedWords.map { $0.text }.joined(separator: " ")
        }

        return linesText.joined(separator: "\n")
    }

    /// Rebuilds leading indentation that OCR discards, from each line's
    /// horizontal offset relative to the left-most line and an estimated
    /// per-character width for that line.
    private func formatCode(_ lines: [TextLine]) -> String {
        guard let baseMinX = lines.map({ $0.minX }).min() else { return "" }

        return lines.map { line -> String in
            let charWidth = codeCharacterWidth(for: line)
            let indentSpaces = charWidth > 0
                ? min(16, max(0, Int(((line.minX - baseMinX) / charWidth).rounded())))
                : 0
            let sortedWords = line.observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let text = sortedWords.map { $0.text }.joined(separator: " ")
            return String(repeating: " ", count: indentSpaces) + text
        }
        .joined(separator: "\n")
    }

    private func codeCharacterWidth(for line: TextLine) -> CGFloat {
        let widths = line.observations.compactMap { observation -> CGFloat? in
            guard !observation.text.isEmpty else { return nil }
            return observation.boundingBox.width / CGFloat(observation.text.count)
        }
        guard !widths.isEmpty else { return 0 }
        return widths.reduce(0, +) / CGFloat(widths.count)
    }

    private func formatTable(_ lines: [TextLine]) -> String {
        let rows = lines.map { line in
            line.observations
                .sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .flatMap { observation -> [String] in
                    let value = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if value.contains("|") {
                        var cells = value.split(separator: "|", omittingEmptySubsequences: false)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        if cells.first?.isEmpty == true { cells.removeFirst() }
                        if cells.last?.isEmpty == true { cells.removeLast() }
                        return cells
                    }
                    if value.contains("\t") {
                        return value.split(separator: "\t", omittingEmptySubsequences: false)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                    // OCR can merge adjacent columns into one observation
                    // separated by runs of spaces; split on those runs to
                    // recover the individual cells.
                    if value.contains("  ") {
                        let cells = value.components(separatedBy: "  ")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        if cells.count > 1 {
                            return cells
                        }
                    }
                    return [value]
                }
                .filter { !$0.isEmpty }
        }

        guard !rows.isEmpty else { return "" }

        let hasTableStructure = rows.contains { $0.count > 1 }
        guard hasTableStructure else {
            return rows.map { $0.first ?? "" }.joined(separator: "\n")
        }

        let dataRows = rows.filter { !isSeparatorRow($0) }
        guard let firstRow = dataRows.first else { return "" }
        let columnCount = dataRows.map(\.count).max() ?? firstRow.count

        // A narrow screenshot can wrap the final cell onto a new OCR row. If
        // that row contains only one value, attach it to the preceding row.
        var mergedRows: [[String]] = []
        for row in dataRows {
            let paddedRow = row + Array(repeating: "", count: max(0, columnCount - row.count))
            let nonEmptyCells = paddedRow.enumerated().filter { !$0.element.isEmpty }
            if nonEmptyCells.count == 1, !mergedRows.isEmpty,
               let targetIndex = mergedRows[mergedRows.count - 1].lastIndex(where: { !$0.isEmpty }) {
                let value = nonEmptyCells[0].element
                // A hyphenated word that wrapped ("Vice-" / "President")
                // rejoins without a separating space.
                if mergedRows[mergedRows.count - 1][targetIndex].hasSuffix("-") {
                    mergedRows[mergedRows.count - 1][targetIndex] += value
                } else {
                    mergedRows[mergedRows.count - 1][targetIndex] += " " + value
                }
            } else {
                mergedRows.append(paddedRow)
            }
        }
        let normalizedRows = mergedRows
        let widths = (0..<columnCount).map { index in
            normalizedRows.map { $0[index].count }.max() ?? 1
        }

        func render(_ row: [String]) -> String {
            let cells = row.enumerated().map { index, value in
                let escaped = value.replacingOccurrences(of: "|", with: "\\|")
                return escaped.padding(toLength: widths[index], withPad: " ", startingAt: 0)
            }
            return "| " + cells.joined(separator: " | ") + " |"
        }

        let separator = "| " + widths.map { String(repeating: "-", count: max(3, $0)) }.joined(separator: " | ") + " |"
        return ([render(normalizedRows[0]), separator] + normalizedRows.dropFirst().map(render)).joined(separator: "\n")
    }

    private func isSeparatorRow(_ row: [String]) -> Bool {
        !row.isEmpty && row.allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && value.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }
    
    private func groupIntoLines(_ observations: [OCRObservation]) -> [TextLine] {
        var lines: [TextLine] = []
        
        for observation in observations.sorted(by: { $0.boundingBox.minY > $1.boundingBox.minY }) {
            let observationCenterY = observation.boundingBox.midY
            let observationHeight = observation.boundingBox.height
            let tolerance = observationHeight * lineGroupingTolerance
            
            if let lineIndex = lines.firstIndex(where: { line in
                abs(line.centerY - observationCenterY) <= tolerance
            }) {
                lines[lineIndex].observations.append(observation)
                lines[lineIndex].updateBounds()
            } else {
                lines.append(TextLine(observations: [observation]))
            }
        }
        
        return lines
    }
}

private struct TextLine {
    var observations: [OCRObservation]
    var minY: CGFloat
    var maxY: CGFloat
    var centerY: CGFloat
    var minX: CGFloat
    var maxX: CGFloat

    init(observations: [OCRObservation]) {
        self.observations = observations
        minY = observations.map { $0.boundingBox.minY }.min() ?? 0
        maxY = observations.map { $0.boundingBox.maxY }.max() ?? 0
        centerY = (minY + maxY) / 2
        minX = observations.map { $0.boundingBox.minX }.min() ?? 0
        maxX = observations.map { $0.boundingBox.maxX }.max() ?? 0
    }

    mutating func updateBounds() {
        guard !observations.isEmpty else { return }
        minY = observations.map { $0.boundingBox.minY }.min() ?? 0
        maxY = observations.map { $0.boundingBox.maxY }.max() ?? 0
        centerY = (minY + maxY) / 2
        minX = observations.map { $0.boundingBox.minX }.min() ?? 0
        maxX = observations.map { $0.boundingBox.maxX }.max() ?? 0
    }
}

final class CodeTextProcessor: TextProcessor {
    private let defaultProcessor = DefaultTextProcessor()

    func process(observations: [OCRObservation], mode: OCRMode = .code) -> String {
        let text = defaultProcessor.process(observations: observations, mode: .code)
        return Self.removingMarkdownFences(Self.joiningTrailingPunctuation(text))
    }

    /// Attaches lone `,` `;` `.` `:` tokens to the preceding word. OCR splits
    /// them into separate observations with padding spaces, and removing the
    /// space before these tokens never changes valid syntax. Leading
    /// indentation is preserved. Wider whitespace/regex normalization is
    /// deliberately avoided because it can alter meaningful indentation and
    /// string literals.
    static func joiningTrailingPunctuation(_ text: String) -> String {
        let attachBackwards: Set<Character> = [",", ";", ".", ":"]
        let joined = text.components(separatedBy: .newlines).map { line -> String in
            let prefix = String(line.prefix(while: { $0 == " " }))
            let tokens = line.dropFirst(prefix.count)
                .split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)
            guard !tokens.isEmpty else { return line }
            var result = tokens[0]
            for token in tokens.dropFirst() {
                if token.count == 1, let character = token.first, attachBackwards.contains(character) {
                    result += token
                } else {
                    result += " " + token
                }
            }
            return prefix + result
        }
        return joined.joined(separator: "\n")
    }

    static func removingMarkdownFences(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        guard let first = lines.first?.trimmingCharacters(in: .whitespaces),
              first.hasPrefix("```") else { return text }

        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
}
