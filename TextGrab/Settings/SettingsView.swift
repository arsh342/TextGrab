import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var shortcutManager: GlobalShortcutManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    
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
            Section("Global Shortcut") {
                HStack {
                    Text("Capture Shortcut:")
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
                        Text("Press a shortcut")
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
                        Text("Capture Saved Area")
                        Text("Copies text from the last selected area without selecting again.")
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
                        Text("Press a shortcut")
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
                    Text(settingsManager.savedRegion == nil ? "No area saved" : "Saved area ready")
                        .foregroundColor(.secondary)
                    Spacer()
                    if settingsManager.savedRegion != nil {
                        Button("Clear") {
                            settingsManager.clearSavedRegion()
                        }
                    }
                }
            }
            
            Section("Behavior") {
                Toggle("Launch at login", isOn: $settingsManager.launchAtLogin)
                Toggle("Show notifications", isOn: $settingsManager.showNotifications)
            }
            
            Section("History") {
                Toggle("Enable clipboard history", isOn: $settingsManager.enableHistory)
                
                if settingsManager.enableHistory {
                    Stepper("Max items: \(settingsManager.maxHistorySize)", value: $settingsManager.maxHistorySize, in: 10...200, step: 10)
                }
            }
            
            Section {
                Button("Reset to Defaults", role: .destructive) {
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
            Section("Recognition") {
                Picker("Extraction Mode", selection: $settingsManager.extractionMode) {
                    ForEach(OCRMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Picker("Recognition Level", selection: $settingsManager.recognitionLevel) {
                    ForEach(OCRConfiguration.RecognitionLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                
                Toggle("Language Correction", isOn: $settingsManager.usesLanguageCorrection)
                    .help("Improves prose but may affect code/technical text")

                if #available(macOS 26.0, *) {
                    Toggle("Correct with Apple Intelligence", isOn: $settingsManager.appleIntelligenceCorrection)
                        .disabled(!appleIntelligenceAvailable)
                        .help("Uses the on-device model to check likely OCR errors before copying")

                    if appleIntelligenceAvailable {
                        Text("Checks OCR text on-device before copying.")
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
            
            Section("Languages") {
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
                    description: "Required to capture screen content; relaunch TextGrab after granting",
                    isGranted: permissionsManager.hasScreenRecordingPermission,
                    action: {
                        Task { _ = await permissionsManager.requestScreenRecordingPermission() }
                    }
                )
                
                PermissionRow(
                    title: "Accessibility",
                    description: "Optional; improves system keyboard integration",
                    isGranted: permissionsManager.hasAccessibilityPermission,
                    action: {
                        _ = permissionsManager.requestAccessibilityPermission()
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
                Text("TextGrab processes all OCR locally on your device. No data is sent to external servers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
    
    var body: some View {
        Form {
            Section("Debug") {
                Toggle("Enable debug logging", isOn: .constant(false))
                    .disabled(true)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Link("Privacy Policy", destination: URL(string: "https://github.com/textgrab/privacy")!)
                Link("Source Code", destination: URL(string: "https://github.com/textgrab/textgrab")!)
            }
        }
        .formStyle(.grouped)
    }
}
