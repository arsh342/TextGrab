import SwiftUI
import CoreGraphics

struct SelectionOverlayView: View {
    let onSelectionComplete: (CGRect) -> Void
    let onCancel: () -> Void
    
    @State private var startPoint: CGPoint?
    @State private var currentRect: CGRect = .zero
    @State private var isSelecting: Bool = false
    
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
        
        let x = min(start.x, value.location.x)
        let y = min(start.y, value.location.y)
        let width = abs(value.location.x - start.x)
        let height = abs(value.location.y - start.y)
        
        currentRect = CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func handleDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        guard isSelecting, currentRect.width > 10, currentRect.height > 10 else {
            resetSelection()
            return
        }
        
        onSelectionComplete(currentRect)
    }
    
    private func resetSelection() {
        startPoint = nil
        currentRect = .zero
        isSelecting = false
    }
}
