import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Sendable snapshot of an NSScreen's capture-relevant properties, so the
/// capture can run inside a `@Sendable` closure without capturing NSScreen.
struct DisplayInfo: Sendable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let backingScaleFactor: CGFloat
    let localizedName: String
}

protocol ScreenCaptureService {
    func capture(display: DisplayInfo, region: CGRect) async throws -> CGImage
}

final class ScreenCaptureManager: ScreenCaptureService {
    private var availableContent: SCShareableContent?

    func capture(display: DisplayInfo, region: CGRect) async throws -> CGImage {
        Logger.shared.debug("Capturing screen region: \(region) on display: \(display.localizedName)")

        var content = try await getShareableContent()
        var scDisplay = content.displays.first(where: { $0.displayID == display.displayID })
        if scDisplay == nil {
            await refreshAvailableContent()
            content = try await getShareableContent()
            scDisplay = content.displays.first(where: { $0.displayID == display.displayID })
        }
        guard let scDisplay else {
            throw TextGrabError.captureFailed("Display not found in shareable content")
        }

        let filter = SCContentFilter(display: scDisplay, excludingApplications: [], exceptingWindows: [])
        let displayFrame = display.frame
        let captureRegion = region
            .insetBy(dx: -2, dy: -2)
            .intersection(displayFrame)
        guard !captureRegion.isNull, captureRegion.width > 0, captureRegion.height > 0 else {
            throw TextGrabError.captureFailed("Selected region is outside the display")
        }
        let localRegion = CGRect(
            x: captureRegion.origin.x - displayFrame.origin.x,
            y: displayFrame.maxY - captureRegion.maxY,
            width: captureRegion.width,
            height: captureRegion.height
        )

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((localRegion.width * display.backingScaleFactor).rounded()))
        configuration.height = max(1, Int((localRegion.height * display.backingScaleFactor).rounded()))
        configuration.sourceRect = localRegion
        configuration.scalesToFit = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

        Logger.shared.debug("Capture completed: \(image.width)x\(image.height)")
        return image
    }
    
    private func getShareableContent() async throws -> SCShareableContent {
        if let cached = availableContent {
            return cached
        }
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        self.availableContent = content
        return content
    }
    
    func refreshAvailableContent() async {
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            Logger.shared.error("Failed to refresh shareable content: \(error)")
        }
    }
}
