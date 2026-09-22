import Foundation
import AppKit
import SwiftUI

@MainActor
protocol SelectionWindowManager: AnyObject {
    func showOverlay(
        on screen: NSScreen,
        content: SelectionOverlayView,
        onSelectionComplete: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    )
    func hideOverlay()
    var isVisible: Bool { get }
}

@MainActor
final class DefaultSelectionWindowManager: SelectionWindowManager {
    private var overlayWindow: NSWindow?
    private var hostingController: NSHostingController<SelectionOverlayView>?
    private var escapeMonitor: Any?

    private(set) var isVisible: Bool = false

    func showOverlay(
        on screen: NSScreen,
        content: SelectionOverlayView,
        onSelectionComplete: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        hideOverlay()

        let frame = screen.frame
        let view = content
            .onSelectionComplete(onSelectionComplete)
            .onCancel(onCancel)

        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = NSRect(origin: .zero, size: frame.size)
        self.hostingController = hostingController

        let window = SelectionPanel(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.hasShadow = false
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.contentViewController = hostingController
        window.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        window.contentView?.autoresizingMask = [.width, .height]
        window.alphaValue = 1

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.hideOverlay()
            onCancel()
            return nil
        }

        self.overlayWindow = window
        self.isVisible = true

        NSApp.activate(ignoringOtherApps: true)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func hideOverlay() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        hostingController = nil
        isVisible = false
    }
}

private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}