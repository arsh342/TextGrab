import Foundation
import FoundationModels
import AppKit

enum AppleIntelligenceOperation {
    case correct
    case summarize
    case compact
}

enum AppleIntelligenceError: LocalizedError {
    case unavailable
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Apple Intelligence is unavailable on this Mac"
        case .emptyResponse: return "Apple Intelligence returned no text"
        }
    }
}

@available(macOS 26.0, *)
final class AppleIntelligenceService {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static func openSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.appleintelligence",
            "x-apple.systempreferences:com.apple.Siri",
            "x-apple.systempreferences:com.apple.settings.Siri"
        ].compactMap(URL.init(string:))

        for url in urls where NSWorkspace.shared.open(url) {
            return
        }
    }

    func transform(_ text: String, operation: AppleIntelligenceOperation, mode: OCRMode) async throws -> String {
        guard Self.isAvailable else { throw AppleIntelligenceError.unavailable }

        let session = LanguageModelSession(
            model: SystemLanguageModel(useCase: .general),
            instructions: "You transform OCR text. Preserve the user's meaning. Return only the transformed text, with no preamble or explanation. Never invent missing information."
        )

        let task: String
        switch operation {
        case .correct:
            task = "Correct likely OCR errors in the text below. Preserve line breaks, punctuation, capitalization, numbers, URLs, and code syntax where intentional. Extraction mode: \(mode.displayName)."
        case .summarize:
            task = "Summarize the text below in a few concise bullet points. Keep names, dates, numbers, decisions, and action items."
        case .compact:
            task = "Make the text below shorter and clearer while preserving every important fact. Keep the original language and use short paragraphs or bullets when helpful."
        }

        let response = try await session.respond(
            to: "\(task)\n\nTEXT:\n\(text)",
            options: GenerationOptions(sampling: .greedy, temperature: 0, maximumResponseTokens: 2_000)
        )
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw AppleIntelligenceError.emptyResponse }
        return result
    }
}
