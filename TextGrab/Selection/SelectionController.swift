import Foundation
import AppKit
import SwiftUI
import CoreGraphics

private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class SelectionController: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var selectedRect: CGRect = .zero
    @Published var currentScreen: NSScreen?
    
    private var overlayWindow: NSWindow?
    private var hostingController: NSHostingController<SelectionOverlayView>?
    private var statusWindow: NSPanel?
    private var statusDismissTask: Task<Void, Never>?
    private var onComplete: ((CGRect, NSScreen?) -> Void)?
    private var onCancel: (() -> Void)?
    private var escapeMonitor: Any?
    
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
        showOverlay(on: screen)
    }
    
    private func showOverlay(on screen: NSScreen) {
        let frame = screen.frame
        
        let view = SelectionOverlayView(
            onSelectionComplete: { [weak self] rect in
                self?.handleSelectionComplete(rect)
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )
        
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
            self?.handleCancel()
            return nil
        }
        
        self.overlayWindow = window
        self.isVisible = true
        
        NSApp.activate(ignoringOtherApps: true)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
    
    private func handleSelectionComplete(_ rect: CGRect) {
        guard rect.width > 10 && rect.height > 10 else {
            handleCancel()
            return
        }
        
        let screenRect = convertToScreenCoordinates(rect)
        selectedRect = screenRect
        isVisible = false
        let completion = onComplete
        cleanup()
        completion?(screenRect, currentScreen)
    }
    
    private func handleCancel() {
        isVisible = false
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
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        hostingController = nil
        onComplete = nil
        onCancel = nil
    }
    
    func cancel() {
        handleCancel()
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
