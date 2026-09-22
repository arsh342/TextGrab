import Foundation
import os

final class Logger {
    static let shared = Logger()

    private let logger: os.Logger
    private let isDebug: Bool

    private init() {
        self.logger = os.Logger(subsystem: "com.textgrab.TextGrab", category: "general")
        #if DEBUG
        self.isDebug = true
        #else
        self.isDebug = false
        #endif
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebug else { return }
        let fileName = (file as NSString).lastPathComponent
        logger.debug("[\(fileName):\(line)] \(function) - \(message)")
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.info("[\(fileName):\(line)] \(function) - \(message)")
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.warning("[\(fileName):\(line)] \(function) - \(message)")
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.error("[\(fileName):\(line)] \(function) - \(message)")
    }
}