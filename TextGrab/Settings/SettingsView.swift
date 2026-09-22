import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var shortcutManager: GlobalShortcutManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    @EnvironmentObject var clipboardManager: ClipboardManager

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            OCRSettingsView()
                .tabItem {
                    Label("OCR", systemImage: "text.viewfinder")
                }

            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            HistorySettingsView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var shortcutManager: GlobalShortcutManager
    @State private var isRecordingShortcut = false
    @State private var isRecordingSavedShortcut = false

    var body: some View {
        Form {
            Section("Shortcuts") {
                HStack {
                    Text("Capture text:")
                    Spacer()
                    Text(shortcutManager.currentShortcut)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    Button("Change...") {
                        isRecordingShortcut = true
                    }
                }

                if isRecordingShortcut {
                    HStack {
                        Text("Press the new shortcut…")
                            .foregroundColor(.secondary)
                        ShortcutRecorderView { keyCode, modifiers, displayString in
                            do {
                                try shortcutManager.updateShortcut(
                                    keyCode: keyCode,
                                    modifiers: modifiers,
                                    displayString: displayString
                                )
                                settingsManager.shortcut = displayString
                                isRecordingShortcut = false
                            } catch {
                                Logger.shared.error("Shortcut change failed: \(error.localizedDescription)")
                            }
                        }
                        .frame(width: 1, height: 1)
                    }
                }
            }

            Section("Saved Area Shortcut") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Capture saved area:")
                        Text("Re-captures the last selected area — no need to drag again.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(shortcutManager.currentSavedShortcut)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    Button("Change...") {
                        isRecordingSavedShortcut = true
                    }
                }

                if isRecordingSavedShortcut {
                    HStack {
                        Text("Press the new shortcut…")
                            .foregroundColor(.secondary)
                        ShortcutRecorderView { keyCode, modifiers, displayString in
                            do {
                                try shortcutManager.updateShortcut(
                                    .savedRegion,
                                    keyCode: keyCode,
                                    modifiers: modifiers,
                                    displayString: displayString
                                )
                                isRecordingSavedShortcut = false
                            } catch {
                                Logger.shared.error("Saved-area shortcut change failed: \(error.localizedDescription)")
                            }
                        }
                        .frame(width: 1, height: 1)
                    }
                }

                HStack {
                    Text(settingsManager.hasSavedRegion ? "Saved area ready" : "No area saved yet")
                        .foregroundColor(.secondary)
                    Spacer()
                    if settingsManager.hasSavedRegion {
                        Button("Clear") {
                            settingsManager.clearSavedRegion()
                        }
                    }
                }
            }

            Section("Behavior") {
                Toggle("Launch TextGrab at login", isOn: $settingsManager.launchAtLogin)
                Toggle("Show a notification when text is copied", isOn: $settingsManager.showNotifications)
            }

            Section {
                Button("Reset All Settings", role: .destructive) {
                    settingsManager.resetToDefaults()
                    do {
                        try shortcutManager.updateShortcut(
                            .selection,
                            keyCode: 19,
                            modifiers: UInt32(cmdKey | shiftKey),
                            displayString: "⌘⇧2"
                        )
                        try shortcutManager.updateShortcut(
                            .savedRegion,
                            keyCode: 19,
                            modifiers: UInt32(cmdKey | optionKey),
                            displayString: "⌘⌥2"
                        )
                    } catch {
                        Logger.shared.error("Failed to reset shortcuts: \(error.localizedDescription)")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct OCRSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var newLanguage = ""
    @State private var appleIntelligenceAvailable = false

    var body: some View {
        Form {
            Section("Extraction") {
                Picker("Extraction Mode", selection: $settingsManager.extractionMode) {
                    ForEach(OCRMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .help("Text for prose, Code for snippets, Table for tabular data")

                Picker("Text Recognition Level", selection: $settingsManager.recognitionLevel) {
                    ForEach(OCRConfiguration.RecognitionLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .help("Fast is quicker; Accurate reads small or complex text better")

                Text("For Fast extraction, switch to Fast recognition level.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Language Correction", isOn: $settingsManager.usesLanguageCorrection)
                    .help("Improves prose but may affect code/technical text")

                if #available(macOS 26.0, *) {
                    Toggle("Correct with Apple Intelligence", isOn: $settingsManager.appleIntelligenceCorrection)
                        .disabled(!appleIntelligenceAvailable)
                        .help("Uses the on-device model to check likely OCR errors before copying")

                    if appleIntelligenceAvailable {
                        Text("Checks OCR text on-device before copying. It may take longer than Fast recognition.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Apple Intelligence must be turned on in System Settings to use this action.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Open Apple Intelligence Settings") {
                                AppleIntelligenceService.openSettings()
                            }
                        }
                    }
                } else {
                    Text("Apple Intelligence requires macOS 26 or later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("OCR Languages") {
                Text("Recognize text in additional languages.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(settingsManager.languages, id: \.self) { lang in
                    HStack {
                        Text(lang)
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    settingsManager.languages.remove(atOffsets: indexSet)
                }

                HStack {
                    TextField("Add language (e.g., fr-FR)", text: $newLanguage)
                    Button("Add") {
                        let language = newLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !language.isEmpty, !settingsManager.languages.contains(language) else { return }
                        settingsManager.languages.append(language)
                        newLanguage = ""
                    }
                    .disabled(newLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshAppleIntelligenceAvailability() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAppleIntelligenceAvailability()
        }
    }

    private func refreshAppleIntelligenceAvailability() {
        if #available(macOS 26.0, *) {
            appleIntelligenceAvailable = AppleIntelligenceService.isAvailable
        } else {
            appleIntelligenceAvailable = false
        }
    }
}

struct PermissionsSettingsView: View {
    @EnvironmentObject var permissionsManager: PermissionsManager

    var body: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to read the selected screen area. Grant it, then relaunch TextGrab.",
                    isGranted: permissionsManager.hasScreenRecordingPermission,
                    action: {
                        Task { _ = await permissionsManager.requestScreenRecordingPermission() }
                    }
                )
            }

            if !permissionsManager.hasScreenRecordingPermission {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen Recording changes take effect after TextGrab is relaunched.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Relaunch TextGrab") {
                            permissionsManager.relaunchApplication()
                        }
                    }
                }
            }

            Section {
                Button("Refresh Permissions") {
                    permissionsManager.checkPermissions()
                }
            }

            Section("Privacy") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("All OCR runs locally on your Mac. Nothing you capture is sent to external servers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link("Privacy Policy", destination: URL(string: "https://github.com/arsh342/TextGrab#security")!)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { permissionsManager.checkPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionsManager.checkPermissions()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(isGranted ? .green : .red)

            if !isGranted {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    let onShortcut: (UInt32, UInt32, String) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onShortcut = onShortcut
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.onShortcut = onShortcut
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class ShortcutRecorderNSView: NSView {
    var onShortcut: ((UInt32, UInt32, String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
            return
        }

        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        let key = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        let displayString = [
            flags.contains(.control) ? "⌃" : nil,
            flags.contains(.option) ? "⌥" : nil,
            flags.contains(.shift) ? "⇧" : nil,
            flags.contains(.command) ? "⌘" : nil,
            key
        ].compactMap { $0 }.joined()

        onShortcut?(UInt32(event.keyCode), carbonModifiers, displayString)
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var updateManager: UpdateManager

    private static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }()

    private static let buildNumber: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }()

    var body: some View {
        Form {
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $settingsManager.checkForUpdatesAutomatically)
                    .help("Checks GitHub Releases at most once a day")

                HStack {
                    Button("Check Now") {
                        Task { await updateManager.checkForUpdates(automatically: false) }
                    }
                    .disabled(updateManager.isChecking)

                    if updateManager.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                switch updateManager.state {
                case .idle:
                    EmptyView()
                case .upToDate:
                    Text("You're up to date (version \(updateManager.currentVersion)).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                case .available(let info):
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TextGrab \(info.version) is available.")
                            .font(.callout)
                        Button("Download Update") {
                            Task { await updateManager.downloadAndOpenUpdate() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                case .failed(let message):
                    Text("Update check failed: \(message)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Self.appVersion)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Self.buildNumber)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Link("User Guide", destination: URL(string: "https://github.com/arsh342/TextGrab#readme")!)
                Link("Privacy Policy", destination: URL(string: "https://github.com/arsh342/TextGrab#security")!)
                Link("Source Code", destination: URL(string: "https://github.com/arsh342/TextGrab")!)
            }
        }
        .formStyle(.grouped)
    }
}

struct HistorySettingsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Form {
            Section("History") {
                Toggle("Keep a history of copied text", isOn: $settingsManager.enableHistory)
                    .help("History stays on this Mac and survives relaunches")

                if settingsManager.enableHistory {
                    Stepper("Keep up to \(settingsManager.maxHistorySize) items in MenuBar", value: $settingsManager.maxHistorySize, in: 10...200, step: 10)
                }

                Button("Clear All History", role: .destructive) {
                    clipboardManager.clearHistory()
                }
            }

            Section("Recent Captures") {
                if clipboardManager.history.isEmpty {
                    Text("No captures yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    List {
                        ForEach(Array(clipboardManager.history.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.text)
                                        .font(.system(size: 11))
                                        .lineLimit(2)
                                        .truncationMode(.tail)

                                    HStack(spacing: 8) {
                                        Text(item.timestamp, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)

                                        Text(item.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    try? clipboardManager.copy(item.text, extractionMode: .normal)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("Copy")

                                Button {
                                    clipboardManager.removeFromHistory(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Delete")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
