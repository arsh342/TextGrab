import Foundation
import AppKit
import SwiftUI
import CoreGraphics

@MainActor
protocol SelectionController: AnyObject {
    var isVisible: Bool { get }
    var selectedRect: CGRect { get }
    var currentScreen: NSScreen? { get }

    func startSelection(onComplete: @escaping (CGRect, NSScreen?) -> Void, onCancel: @escaping () -> Void)
    func cancel()
    func showStatus(_ message: String?, on screen: NSScreen?)
}

@MainActor
final class DefaultSelectionController: SelectionController {
    private let windowManager: SelectionWindowManager

    @Published private(set) var isVisible: Bool = false
    @Published private(set) var selectedRect: CGRect = .zero
    @Published private(set) var currentScreen: NSScreen?

    private var onComplete: ((CGRect, NSScreen?) -> Void)?
    private var onCancel: (() -> Void)?
    private var statusWindow: NSPanel?
    private var statusDismissTask: Task<Void, Never>?

    init(windowManager: SelectionWindowManager) {
        self.windowManager = windowManager
    }

    static func makeDefault() -> DefaultSelectionController {
        let windowManager = DefaultSelectionWindowManager()
        return DefaultSelectionController(windowManager: windowManager)
    }

    func startSelection(onComplete: @escaping (CGRect, NSScreen?) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel

        let cursorLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorLocation) })
                ?? NSScreen.main ?? NSScreen.screens.first else {
            onCancel()
            return
        }

        currentScreen = screen
        isVisible = true

        windowManager.showOverlay(
            on: screen,
            content: SelectionOverlayView(),
            onSelectionComplete: { [weak self] rect in
                self?.handleSelectionComplete(rect)
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )
    }

    func cancel() {
        handleCancel()
    }

    private func handleSelectionComplete(_ rect: CGRect) {
        guard rect.width > 10 && rect.height > 10 else {
            handleCancel()
            return
        }

        let screenRect = convertToScreenCoordinates(rect)
        selectedRect = screenRect
        isVisible = false
        windowManager.hideOverlay()
        let completion = onComplete
        cleanup()
        completion?(screenRect, currentScreen)
    }

    private func handleCancel() {
        isVisible = false
        windowManager.hideOverlay()
        let cancellation = onCancel
        cleanup()
        cancellation?()
    }

    private func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
        guard let screen = currentScreen else { return rect }

        let screenFrame = screen.frame
        return CGRect(
            x: screenFrame.origin.x + rect.origin.x,
            y: screenFrame.origin.y + screenFrame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private func cleanup() {
        onComplete = nil
        onCancel = nil
    }

    func showStatus(_ message: String? = nil, on screen: NSScreen?) {
        statusDismissTask?.cancel()
        statusWindow?.orderOut(nil)

        let view = StatusPillView(message: message)
        let hostingController = NSHostingController(rootView: view)
        let size = NSSize(width: message == nil ? 64 : 240, height: 58)
        let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let origin = CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.minY + 88
        )

        let window = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.contentViewController = hostingController
        hostingController.view.frame = NSRect(origin: .zero, size: size)
        window.contentView?.frame = NSRect(origin: .zero, size: size)
        window.contentView?.autoresizingMask = [.width, .height]
        window.orderFrontRegardless()
        statusWindow = window

        statusDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            self?.statusWindow?.orderOut(nil)
            self?.statusWindow = nil
        }
    }
}

private struct StatusPillView: View {
    let message: String?

    var body: some View {
        Group {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityLabel("Copied")
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, message == nil ? 14 : 18)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}