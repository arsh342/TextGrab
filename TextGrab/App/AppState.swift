import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum State: Equatable {
        case idle
        case selecting
        case capturing
        case processing
        case copied(String)
        case error(Error)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.selecting, .selecting), (.capturing, .capturing), (.processing, .processing):
                return true
            case (.copied(let lhsText), .copied(let rhsText)):
                return lhsText == rhsText
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }

    @Published var currentState: State = .idle
    @Published var isProcessing: Bool = false
    @Published var lastCapturedText: String?
    @Published var lastError: TextGrabError?

    func transition(to newState: State) {
        Logger.shared.debug("State transition: \(stateName(currentState)) -> \(stateName(newState))")
        currentState = newState
        
        switch newState {
        case .idle:
            isProcessing = false
            lastError = nil
        case .selecting:
            isProcessing = true
            lastError = nil
        case .capturing:
            isProcessing = true
            lastError = nil
        case .processing:
            isProcessing = true
            lastError = nil
        case .copied(let text):
            isProcessing = false
            lastCapturedText = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if self.currentState == .copied(text) {
                    self.transition(to: .idle)
                }
            }
        case .error(let error):
            isProcessing = false
            lastError = error as? TextGrabError ?? TextGrabError.unknown(error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .error = self.currentState {
                    self.transition(to: .idle)
                }
            }
        }
    }

    private func stateName(_ state: State) -> String {
        switch state {
        case .idle: return "idle"
        case .selecting: return "selecting"
        case .capturing: return "capturing"
        case .processing: return "processing"
        case .copied: return "copied"
        case .error: return "error"
        }
    }
}

enum TextGrabError: LocalizedError, Equatable {
    case permissionDenied(String)
    case captureFailed(String)
    case ocrFailed(String)
    case clipboardFailed(String)
    case shortcutRegistrationFailed(String)
    case aiFailed(String)
    case operationTimedOut(TimeInterval)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .captureFailed(let message):
            return "Capture failed: \(message)"
        case .ocrFailed(let message):
            return "OCR failed: \(message)"
        case .clipboardFailed(let message):
            return "Clipboard failed: \(message)"
        case .shortcutRegistrationFailed(let message):
            return "Shortcut registration failed: \(message)"
        case .aiFailed(let message):
            return "Apple Intelligence failed: \(message)"
        case .operationTimedOut(let seconds):
            return "Timed out after \(Int(seconds))s — try a smaller selection"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    static func == (lhs: TextGrabError, rhs: TextGrabError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
