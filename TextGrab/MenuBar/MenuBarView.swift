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
            }

            Divider()
            footerView
        }
        .frame(width: 380, height: 460)
    }
    
    private var headerView: some View {
        HStack {
            Text("TextGrab")
                .font(.system(size: 12, weight: .bold))
            Spacer()
            extractionModeView
        }
        .padding(.horizontal, 12)
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
                Label {
                    Text("Capture Text")
                    Spacer()
                    Text(shortcutManager.currentShortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "camera.viewfinder")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(appState.isProcessing)

            Button {
                dismiss()
                Task { @MainActor in
                    await captureCoordinator.retryLastCapture()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(settingsManager.savedRegion == nil || appState.isProcessing)
            .help("Capture the last selected area again")
        }
        .buttonStyle(.bordered)
    }

    private var extractionModeView: some View {
        Picker("Extraction mode", selection: $settingsManager.extractionMode) {
            ForEach(OCRMode.allCases, id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .help(settingsManager.extractionMode.displayName)
        .fixedSize()
    }
    
    private var progressView: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text(processingText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 0)
    }
    
    private var processingText: String {
        switch appState.currentState {
        case .selecting: return "Select area..."
        case .capturing: return "Capturing screen..."
        case .processing: return "Recognizing text..."
        default: return "Processing..."
        }
    }
    
    private func errorView(_ error: TextGrabError) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error.errorDescription ?? "Unknown error")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 0)
    }
    
    private func lastCaptureView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Last Capture")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Copy") {
                    do {
                        try clipboardManager.copy(text)
                    } catch let error as TextGrabError {
                        appState.transition(to: .error(error))
                    } catch {
                        appState.transition(to: .error(TextGrabError.clipboardFailed(error.localizedDescription)))
                    }
                }
                .font(.caption)

                Button(speechManager.isSpeaking ? "Stop" : "Speak") {
                    if speechManager.isSpeaking {
                        speechManager.stop()
                    } else {
                        speechManager.speak(text)
                    }
                }
                .font(.caption)
            }
            
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(4)

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
        .padding(.horizontal, 0)
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent Captures")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear") { clipboardManager.clearHistory() }
                    .font(.caption)
            }

            ForEach(Array(clipboardManager.history.prefix(20).enumerated()), id: \.offset) { index, item in
                Button {
                    do {
                        try clipboardManager.copy(item)
                    } catch let error as TextGrabError {
                        appState.transition(to: .error(error))
                    } catch {
                        appState.transition(to: .error(TextGrabError.clipboardFailed(error.localizedDescription)))
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .center)

                        Text(historyPreview(item))
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(minHeight: 30)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Copy capture \(index + 1)")
            }
        }
        .padding(.horizontal, 0)
        .padding(.top, 2)
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
            
            Spacer()
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}
