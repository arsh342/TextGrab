import Foundation
import SwiftUI
import AppKit
import CoreGraphics

@MainActor
final class CaptureCoordinator: ObservableObject {
    private let pipeline: CapturePipeline
    private var triggerObserver: NSObjectProtocol?
    private var savedTriggerObserver: NSObjectProtocol?

    init(pipeline: CapturePipeline) {
        self.pipeline = pipeline
        self.triggerObserver = NotificationCenter.default.addObserver(
            forName: .triggerCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await self?.startCapture()
            }
        }
        self.savedTriggerObserver = NotificationCenter.default.addObserver(
            forName: .triggerSavedCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await self?.captureSavedRegion()
            }
        }
    }

    deinit {
        if let triggerObserver {
            NotificationCenter.default.removeObserver(triggerObserver)
        }
        if let savedTriggerObserver {
            NotificationCenter.default.removeObserver(savedTriggerObserver)
        }
    }

    func startCapture() async throws {
        _ = try await pipeline.capture(region: nil, on: nil)
    }

    func captureSavedRegion() async throws {
        _ = try await pipeline.captureSavedRegion()
    }

    func retryLastCapture() async throws {
        _ = try await pipeline.transformLast(.correct)
    }

    func transformLastCapture(_ operation: AITransform) async throws {
        _ = try await pipeline.transformLast(operation)
    }
}