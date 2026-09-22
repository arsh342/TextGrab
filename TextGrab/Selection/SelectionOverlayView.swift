import SwiftUI
import CoreGraphics

struct SelectionOverlayView: View {
    @State private var startPoint: CGPoint?
    @State private var currentRect: CGRect = .zero
    @State private var isSelecting: Bool = false

    var onSelectionComplete: (CGRect) -> Void = { _ in }
    var onCancel: () -> Void = { }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !isSelecting {
                            onCancel()
                        }
                    }

                if isSelecting || currentRect != .zero {
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.1))
                        .frame(width: max(currentRect.width, 1), height: max(currentRect.height, 1))
                        .position(x: currentRect.midX, y: currentRect.midY)
                        .overlay(alignment: .bottomTrailing) {
                            if currentRect.width > 50 && currentRect.height > 30 {
                                Text("\(Int(currentRect.width)) × \(Int(currentRect.height))")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())
                                    .offset(x: -8, y: -8)
                            }
                        }
                }

                Text(instructionsText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 96)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value, in: geometry.size)
                    }
                    .onEnded { value in
                        handleDragEnded(value, in: geometry.size)
                    }
            )
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
        }
        .ignoresSafeArea()
    }

    private var instructionsText: String {
        if isSelecting {
            return "Drag to select area • Release to capture • Esc to cancel"
        } else {
            return "Click and drag to select text area • Esc to cancel"
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        if startPoint == nil {
            startPoint = value.startLocation
            isSelecting = true
        }

        guard let start = startPoint else { return }

        // Clamp both start and end points to bounds first
        let clampedStartX = max(0, min(start.x, size.width))
        let clampedStartY = max(0, min(start.y, size.height))
        let clampedEndX = max(0, min(value.location.x, size.width))
        let clampedEndY = max(0, min(value.location.y, size.height))

        // Compute rect from clamped endpoints
        let x = min(clampedStartX, clampedEndX)
        let y = min(clampedStartY, clampedEndY)
        let width = abs(clampedEndX - clampedStartX)
        let height = abs(clampedEndY - clampedStartY)

        currentRect = CGRect(x: x, y: y, width: width, height: height)
    }

    private func handleDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        guard isSelecting, currentRect.width > 10, currentRect.height > 10 else {
            resetSelection()
            return
        }

        // Final clamp to ensure validity (should already be clamped, but double-check)
        let clampedRect = currentRect.intersection(CGRect(origin: .zero, size: size))
        guard clampedRect.width > 10, clampedRect.height > 10 else {
            resetSelection()
            return
        }

        onSelectionComplete(clampedRect)
    }

    private func resetSelection() {
        startPoint = nil
        currentRect = .zero
        isSelecting = false
    }
}

extension SelectionOverlayView {
    func onSelectionComplete(_ action: @escaping (CGRect) -> Void) -> SelectionOverlayView {
        var copy = self
        copy.onSelectionComplete = action
        return copy
    }

    func onCancel(_ action: @escaping () -> Void) -> SelectionOverlayView {
        var copy = self
        copy.onCancel = action
        return copy
    }
}