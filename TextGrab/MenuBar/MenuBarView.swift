import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DefaultMenuBarViewModel

    init(viewModel: DefaultMenuBarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    actionRow

                    if viewModel.isProcessing {
                        progressView
                    }

                    if let error = viewModel.lastError {
                        errorView(error)
                    }

                    if let text = viewModel.lastCapture {
                        lastCaptureView(text)
                    }

                    if viewModel.enableHistory && !viewModel.history.isEmpty {
                        historyView
                    }
                }
                .padding(14)
                .animation(.snappy(duration: 0.18), value: viewModel.isProcessing)
                .animation(.snappy(duration: 0.18), value: viewModel.history)
            }

            Divider()
            footerView
        }
        .frame(width: 380, height: 460)
        .background(WindowPositionAdjuster(offset: 40))
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("TextGrab")
                .font(.system(size: 13, weight: .bold))
            Spacer()
            extractionModeView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
                viewModel.captureAction()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                    Text("Capture Text")
                    Spacer()
                    Text(viewModel.currentShortcut)
                        .font(.caption2.monospacedDigit())
                        .opacity(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isProcessing)
            .accessibilityIdentifier("captureTextButton")
            .help("Select a region of the screen and copy its text")

            Button {
                dismiss()
                viewModel.retryAction()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!viewModel.hasSavedRegion || viewModel.isProcessing)
            .help("Capture the last selected area again")
        }
    }

    private var extractionModeView: some View {
        HStack(spacing: 2) {
            ForEach(OCRMode.allCases, id: \.self) { mode in
                modeSegment(for: mode)
            }
        }
        .padding(3)
        .background(
            Color(nsColor: .textBackgroundColor).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .help("How captured text is processed")
    }

    private func modeSegment(for mode: OCRMode) -> some View {
        let isSelected = mode == viewModel.extractionMode
        return Button {
            viewModel.extractionMode = mode
        } label: {
            Label(mode.displayName, systemImage: mode.systemImage)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    isSelected ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.primary.opacity(0.12) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help("\(mode.displayName) extraction")
    }

    private var progressView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(viewModel.processingText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func errorView(_ error: TextGrabError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(error.errorDescription ?? "Unknown error")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .transition(.opacity)
    }

    private func lastCaptureView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Last Capture")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    viewModel.copyText(text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption)
                .controlSize(.small)

                Button {
                    if viewModel.isSpeaking {
                        viewModel.stopSpeaking()
                    } else {
                        viewModel.speakLastCapture()
                    }
                } label: {
                    Label(
                        viewModel.isSpeaking ? "Stop" : "Speak",
                        systemImage: viewModel.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                    )
                }
                .font(.caption)
                .controlSize(.small)
            }

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    Color(nsColor: .textBackgroundColor).opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 6)
                )

            if #available(macOS 26.0, *), AppleIntelligenceService.isAvailable {
                HStack(spacing: 6) {
                    Button {
                        viewModel.transformLast(.summarize)
                    } label: {
                        if viewModel.isTransforming && viewModel.transformingOperation == .summarize {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 14, height: 14)
                        } else {
                            Label("Summarize", systemImage: "list.bullet.indent")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isProcessing || viewModel.isTransforming)

                    Button {
                        viewModel.transformLast(.compact)
                    } label: {
                        if viewModel.isTransforming && viewModel.transformingOperation == .compact {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 14, height: 14)
                        } else {
                            Label("Compact", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isProcessing || viewModel.isTransforming)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent Captures")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { viewModel.clearHistory() }
                    .font(.caption)
                    .controlSize(.small)
            }

            ForEach(Array(viewModel.history.prefix(viewModel.maxHistorySize).enumerated()), id: \.offset) { index, item in
                HistoryRow(index: index, item: item, onCopy: {
                    viewModel.copyFromHistory(item)
                }, onDelete: {
                    viewModel.deleteFromHistory(item)
                })
            }
        }
    }

    private func historyPreview(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .joined(separator: "  ·  ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var footerView: some View {
        HStack {
            Button("Settings") {
                openSettings()
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }
            .font(.caption)
            .accessibilityIdentifier("settingsButton")

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct HistoryRow: View {
    let index: Int
    let item: HistoryItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(item.text)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(isHovering ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundStyle(isHovering ? Color.red : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 30)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering
                        ? Color.accentColor.opacity(0.15)
                        : Color(nsColor: .textBackgroundColor).opacity(0.55)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isHovering ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .onHover { isHovering = $0 }
    }
}

/// The system pins the MenuBarExtra window to the far right edge of the
/// screen. Nudges it left once per opening so it is not flush against the
/// screen edge.
private struct WindowPositionAdjuster: NSViewRepresentable {
    let offset: CGFloat

    func makeNSView(context: Context) -> AdjusterNSView {
        let view = AdjusterNSView()
        view.offset = offset
        return view
    }

    func updateNSView(_ nsView: AdjusterNSView, context: Context) {
        nsView.offset = offset
    }

    final class AdjusterNSView: NSView {
        var offset: CGFloat = 40
        private var hasAdjusted = false
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            if observers.isEmpty { installObservers() }
            hasAdjusted = false
            DispatchQueue.main.async {
                self.resetAndAdjust()
            }
        }

        private func installObservers() {
            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in self?.resetAndAdjust() })
            observers.append(center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in self?.resetAndAdjust() })
        }

        private func resetAndAdjust() {
            guard let window, window.occlusionState.contains(.visible) else {
                hasAdjusted = false
                return
            }
            guard !hasAdjusted else { return }
            hasAdjusted = true
            var frame = window.frame
            frame.origin.x -= offset
            window.setFrame(frame, display: true)
        }

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}