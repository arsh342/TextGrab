import Foundation
import AppKit
import Combine

protocol ClipboardService {
    func copy(_ text: String, extractionMode: OCRMode) throws
    func copy(_ text: String) throws
    func getString() -> String?
}

struct HistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    init(text: String) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
    }
    
    var displayDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            return "Today"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: timestamp)
        }
    }
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: timestamp)
    }
}

final class ClipboardManager: ClipboardService, ObservableObject {
    @Published var lastCopiedText: String?
    @Published var history: [HistoryItem] = []
    
    private static let historyDefaultsKey = "clipboardHistory"
    private var historyEnabled = false
    private var maxHistorySize = 20
    private let pasteboard = NSPasteboard.general
    private var settingsCancellable: AnyCancellable?
    private var historyCancellable: AnyCancellable?
    private var persistTask: Task<Void, Never>?
    private let persistQueue = DispatchQueue(label: "com.textgrab.clipboard.persist", qos: .utility)

    init(settings: SettingsManager) {
        historyEnabled = settings.enableHistory
        maxHistorySize = max(1, settings.maxHistorySize)
        history = Self.loadPersistedHistory(enabled: historyEnabled, limit: maxHistorySize)
        settingsCancellable = settings.$history
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.historyEnabled = config.enabled
                self?.maxHistorySize = max(1, config.maxSize)
                if !config.enabled {
                    self?.history.removeAll()
                    self?.schedulePersist()
                } else if let self, self.history.count > self.maxHistorySize {
                    self.history = Array(self.history.prefix(self.maxHistorySize))
                    self.schedulePersist()
                }
            }
        // Debounced persistence on background queue
        historyCancellable = $history
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.schedulePersist()
            }
    }

    func copy(_ text: String, extractionMode: OCRMode = .normal) throws {
        Logger.shared.debug("Copying text to clipboard: \(text.count) characters")

        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        // Only generate HTML representation for table mode to avoid parsing overhead
        if extractionMode == .table,
           let tableHTML = HTMLTableClipboardRepresentation.html(from: text) {
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

    func copy(_ text: String) throws {
        try copy(text, extractionMode: .normal)
    }

    func getString() -> String? {
        pasteboard.string(forType: .string)
    }

    private func addToHistory(_ text: String) {
        guard historyEnabled else { return }
        let trimmed = text.trimmingWhitespaceAndNewlines()
        guard trimmed.isNotEmpty else { return }

        history.removeAll { $0.text == trimmed }
        history.insert(HistoryItem(text: trimmed), at: 0)

        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }
    }

    func clearHistory() {
        history.removeAll()
        schedulePersist()
    }

    func removeFromHistory(_ item: HistoryItem) {
        history.removeAll { $0.id == item.id }
        schedulePersist()
    }

    /// History survives app relaunches: bounded, opt-in, stored in UserDefaults.
    /// Persistence runs on a background queue to avoid main-thread hitches.
    private func schedulePersist() {
        persistTask?.cancel()
        let items = history
        let enabled = historyEnabled
        let limit = maxHistorySize
        persistTask = Task.detached(priority: .utility) { [persistQueue] in
            await persistQueue.async {
                Self.persistHistoryStatic(items, enabled: enabled, limit: limit)
            }
        }
    }

    private static func persistHistoryStatic(_ items: [HistoryItem], enabled: Bool, limit: Int) {
        guard enabled, !items.isEmpty else {
            UserDefaults.standard.removeObject(forKey: historyDefaultsKey)
            return
        }
        let bounded = Array(items.prefix(limit))
        if let data = try? JSONEncoder().encode(bounded) {
            UserDefaults.standard.set(data, forKey: historyDefaultsKey)
        }
    }

    private static func loadPersistedHistory(enabled: Bool, limit: Int) -> [HistoryItem] {
        guard enabled,
              let data = UserDefaults.standard.data(forKey: historyDefaultsKey),
              let items = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
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

        var cells: [String] = []
        var currentCell = ""
        var i = 0
        let chars = Array(trimmed)

        while i < chars.count {
            let char = chars[i]
            if char == "|" {
                // Check if this is an escaped pipe
                if i > 0 && chars[i - 1] == "\\" {
                    // Escaped pipe - add to current cell (but remove the backslash)
                    currentCell = String(currentCell.dropLast()) + "|"
                } else {
                    // Regular delimiter
                    cells.append(currentCell.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentCell = ""
                }
            } else {
                currentCell.append(char)
            }
            i += 1
        }

        // Add the last cell
        cells.append(currentCell.trimmingCharacters(in: .whitespacesAndNewlines))

        // Remove first and last if empty (due to leading/trailing |)
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }

        return cells
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
