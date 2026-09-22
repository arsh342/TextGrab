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
/// Uses independent tasks with a one-shot completion gate so the deadline
/// wins immediately without waiting for the loser to acknowledge cancellation.
func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        let gate = NIOLockedValueBox<Bool>(false)

        group.addTask { @Sendable in
            let result = try await operation()
            let shouldReturn = gate.withLockedValue { completed in
                if !completed {
                    completed = true
                    return true
                }
                return false
            }
            if !shouldReturn {
                throw CancellationError()
            }
            return result
        }

        group.addTask { @Sendable in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            let shouldThrow = gate.withLockedValue { completed in
                if !completed {
                    completed = true
                    return true
                }
                return false
            }
            if shouldThrow {
                throw TextGrabError.operationTimedOut(seconds)
            }
            // If we reach here, the operation already completed.
            // Throw cancellation to satisfy the task group's return type.
            throw CancellationError()
        }

        guard let result = try await group.next() else {
            throw TextGrabError.operationTimedOut(seconds)
        }
        group.cancelAll()
        return result
    }
}

@available(macOS 10.15, iOS 13.0, *)
final class NIOLockedValueBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLockedValue<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
