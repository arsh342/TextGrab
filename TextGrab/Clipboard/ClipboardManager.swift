import Foundation
import AppKit
import Combine

protocol ClipboardService {
    func copy(_ text: String) throws
    func getString() -> String?
}

final class ClipboardManager: ClipboardService, ObservableObject {
    @Published var lastCopiedText: String?
    @Published var history: [String] = []

    private static let historyDefaultsKey = "clipboardHistory"
    private var historyEnabled = false
    private var maxHistorySize = 50
    private let pasteboard = NSPasteboard.general
    private var settingsCancellable: AnyCancellable?
    private var historyCancellable: AnyCancellable?

    init(settings: SettingsManager) {
        historyEnabled = settings.enableHistory
        maxHistorySize = max(1, settings.maxHistorySize)
        history = Self.loadPersistedHistory(enabled: historyEnabled, limit: maxHistorySize)
        settingsCancellable = Publishers.CombineLatest(
            settings.$enableHistory,
            settings.$maxHistorySize
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] enabled, size in
            self?.historyEnabled = enabled
            self?.maxHistorySize = max(1, size)
            if !enabled {
                self?.history.removeAll()
            } else if let self, self.history.count > self.maxHistorySize {
                self.history = Array(self.history.prefix(self.maxHistorySize))
            }
        }
        historyCancellable = $history
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.persistHistory(items)
            }
    }
    
    func copy(_ text: String) throws {
        Logger.shared.debug("Copying text to clipboard: \(text.count) characters")
        
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        if let tableHTML = HTMLTableClipboardRepresentation.html(from: text) {
            pasteboard.setData(Data(tableHTML.utf8), forType: .html)
        }
        
        guard success else {
            Logger.shared.error("Failed to copy to clipboard")
            throw TextGrabError.clipboardFailed("Unable to write to pasteboard")
        }
        
        lastCopiedText = text
        addToHistory(text)
        
        Logger.shared.debug("Successfully copied to clipboard")
    }
    
    func getString() -> String? {
        pasteboard.string(forType: .string)
    }
    
    private func addToHistory(_ text: String) {
        guard historyEnabled else { return }
        let trimmed = text.trimmingWhitespaceAndNewlines()
        guard trimmed.isNotEmpty else { return }

        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)

        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }
    }

    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.historyDefaultsKey)
    }

    /// History survives app relaunches: bounded, opt-in, stored in UserDefaults.
    private func persistHistory(_ items: [String]) {
        guard historyEnabled, !items.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.historyDefaultsKey)
            return
        }
        let bounded = Array(items.prefix(maxHistorySize))
        if let data = try? JSONEncoder().encode(bounded) {
            UserDefaults.standard.set(data, forKey: Self.historyDefaultsKey)
        }
    }

    private static func loadPersistedHistory(enabled: Bool, limit: Int) -> [String] {
        guard enabled,
              let data = UserDefaults.standard.data(forKey: historyDefaultsKey),
              let items = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Array(items.prefix(limit))
    }
}

private enum HTMLTableClipboardRepresentation {
    static func html(from markdown: String) -> String? {
        let rawRows = markdown
            .split(whereSeparator: \.isNewline)
            .map { parseRow(String($0)) }
            .compactMap { $0 }

        guard rawRows.count >= 2,
              rawRows.allSatisfy({ $0.count > 1 }),
              rawRows.dropFirst().contains(where: isSeparatorRow) else {
            return nil
        }

        let rows = rawRows.filter { !isSeparatorRow($0) }
        guard let columnCount = rows.map(\.count).max(), columnCount > 1 else { return nil }

        let normalizedRows = rows.map { row in
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }
        let header = normalizedRows[0]
        let body = normalizedRows.dropFirst()

        var output = "<table>"
        output += "<thead><tr>" + header.map { "<th>\(escape($0))</th>" }.joined() + "</tr></thead>"
        output += "<tbody>"
        for row in body {
            output += "<tr>" + row.map { "<td>\(escape($0))</td>" }.joined() + "</tr>"
        }
        output += "</tbody></table>"
        return "<html><head><meta charset=\"utf-8\"></head><body>\(output)</body></html>"
    }

    private static func parseRow(_ row: String) -> [String]? {
        let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("|") else { return nil }
        var cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells.map { $0.replacingOccurrences(of: "\\|", with: "|") }
    }

    private static func isSeparatorRow(_ row: [String]) -> Bool {
        !row.isEmpty && row.allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && value.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
