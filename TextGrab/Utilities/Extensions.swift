import Foundation
import CoreGraphics
import AppKit

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    
    func scaled(by factor: CGFloat) -> CGRect {
        CGRect(x: origin.x * factor, y: origin.y * factor, width: size.width * factor, height: size.height * factor)
    }
    
    func integral() -> CGRect {
        CGRect(x: floor(origin.x), y: floor(origin.y), width: ceil(size.width), height: ceil(size.height))
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

extension CGImage {
    var pngData: Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: self)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}

extension String {
    func trimmingWhitespaceAndNewlines() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isNotEmpty: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Array where Element == String {
    func joinedWithNewlines() -> String {
        joined(separator: "\n")
    }
}

/// Races `operation` against a timer so a hung system call (ScreenCaptureKit,
/// Vision, Foundation Models) can never leave the app stuck in `.processing`.
func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask(operation: operation)
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TextGrabError.operationTimedOut(seconds)
        }
        guard let result = try await group.next() else {
            throw TextGrabError.operationTimedOut(seconds)
        }
        group.cancelAll()
        return result
    }
}
