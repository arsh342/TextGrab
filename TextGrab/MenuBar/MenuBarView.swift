import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var shortcutManager: GlobalShortcutManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var speechManager: TextToSpeechManager
    @EnvironmentObject var captureCoordinator: CaptureCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    actionRow

                    if appState.isProcessing {
                        progressView
                    }

                    if let error = appState.lastError {
                        errorView(error)
                    }

                    if let text = appState.lastCapturedText {
                        lastCaptureView(text)
                    }

                    if settingsManager.enableHistory && !clipboardManager.history.isEmpty {
                        historyView
                    }
                }
                .padding(14)
                .animation(.snappy(duration: 0.18), value: appState.isProcessing)
                .animation(.snappy(duration: 0.18), value: clipboardManager.history)
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
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .triggerCapture, object: nil)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                    Text("Capture Text")
                    Spacer()
                    Text(shortcutManager.currentShortcut)
                        .font(.caption2.monospacedDigit())
                        .opacity(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.isProcessing)
            .accessibilityIdentifier("captureTextButton")
            .help("Select a region of the screen and copy its text")

            Button {
                dismiss()
                Task { @MainActor in
                    await captureCoordinator.retryLastCapture()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(settingsManager.savedRegion == nil || appState.isProcessing)
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
        let isSelected = mode == settingsManager.extractionMode
        return Button {
            settingsManager.extractionMode = mode
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
            Text(processingText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var processingText: String {
        switch appState.currentState {
        case .selecting: return String(localized: "Select area...")
        case .capturing: return String(localized: "Capturing screen...")
        case .processing: return String(localized: "Recognizing text...")
        default: return String(localized: "Processing...")
        }
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
                    copy(text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption)
                .controlSize(.small)

                Button {
                    if speechManager.isSpeaking {
                        speechManager.stop()
                    } else {
                        speechManager.speak(text)
                    }
                } label: {
                    Label(
                        speechManager.isSpeaking ? "Stop" : "Speak",
                        systemImage: speechManager.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
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
                        Task { @MainActor in
                            await captureCoordinator.transformLastCapture(.summarize)
                        }
                    } label: {
                        Label("Summarize", systemImage: "list.bullet.indent")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(appState.isProcessing)

                    Button {
                        Task { @MainActor in
                            await captureCoordinator.transformLastCapture(.compact)
                        }
                    } label: {
                        Label("Compact", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(appState.isProcessing)
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
                Button("Clear") { clipboardManager.clearHistory() }
                    .font(.caption)
                    .controlSize(.small)
            }

            ForEach(Array(clipboardManager.history.prefix(20).enumerated()), id: \.offset) { index, item in
                HistoryRow(index: index, text: historyPreview(item)) {
                    copy(item)
                }
            }
        }
    }

    private func historyPreview(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .joined(separator: "  ·  ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copy(_ text: String) {
        do {
            try clipboardManager.copy(text)
        } catch let error as TextGrabError {
            appState.transition(to: .error(error))
        } catch {
            appState.transition(to: .error(TextGrabError.clipboardFailed(error.localizedDescription)))
        }
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
    let text: String
    let onCopy: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(text)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(isHovering ? Color.primary : Color.secondary)
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
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Copy capture \(index + 1)")
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
