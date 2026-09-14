# TextGrab

[▶ Watch demo video](resources/textgrab_vid.mp4)

Native macOS utility for extracting text from anywhere on the screen.

**Tagline:** Instant screen-to-text for macOS.

## Core Workflow

1. Press the global TextGrab shortcut (default: `⌘⇧2`)
2. Select a region of the screen
3. TextGrab captures that region
4. Apple Vision performs local OCR
5. Recognized text is copied to the clipboard

```text
Shortcut → Select → Capture → OCR → Clipboard
```

## Features

### Capture & OCR
- **Global shortcut** — Configurable system-wide hotkey for instant capture
- **Saved area capture** — Secondary shortcut (`⌘⌥2` by default) to re-capture the last selected region without re-selecting
- **Multi-monitor support** — Works across all connected displays
- **Three extraction modes:**
  - **Text** — General purpose text extraction with language correction
  - **Code** — Optimized for code snippets (disables language correction)
  - **Table** — Extracts tabular data as markdown/CSV
- **Recognition levels** — Fast or Accurate (Vision framework)
- **Multi-language OCR** — Add custom languages (e.g., `fr-FR`, `ja-JP`, `zh-Hans`)

### Clipboard & History
- **Clipboard history** — Optional in-memory history with configurable max items (10–200)
- **One-click recopy** — Click any history item to copy it again

### Text-to-Speech
- **Speak captured text** — Built-in TTS with play/stop controls in the menu bar

### Apple Intelligence (macOS 26+)
- **On-device correction** — Uses Apple Intelligence to fix OCR errors before copying (runs entirely on-device, no cloud)
- **Summarize** — Generate a concise summary of captured text with one click
- **Compact** — Create a condensed version preserving key information
- **Privacy-first** — All processing happens locally; no data leaves your Mac

### Menu Bar Interface
- Quick access to capture, retry, history, and settings
- Live extraction mode picker (Text/Code/Table)
- Real-time processing status

### Privacy & Permissions
- **100% local processing** — No data sent to external servers
- **Permission management** — Built-in UI for Screen Recording and Accessibility permissions
- **Relaunch helper** — One-click app restart after granting permissions

### Settings
- **General** — Shortcuts, notifications, history
- **OCR** — Mode, recognition level, language correction, Apple Intelligence, languages
- **Permissions** — Grant/check Screen Recording & Accessibility
- **Advanced** — Version info, links to source/privacy

## Goals

- Native Swift/macOS implementation
- Fast screen-to-text workflow
- Local OCR; no cloud service required for the core path
- Menu-bar-first UX
- Multi-monitor support
- Minimal external dependencies
- Strong privacy defaults

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI + AppKit
- **Frameworks:** Vision, ScreenCaptureKit, CoreGraphics, Foundation, Carbon (for global shortcuts)
- **Architecture:** MVVM with `@ObservableObject`/`@StateObject`
- **Testing:** Swift Testing (unit), XCUITest (UI)

## Repository Layout

```text
TextGrab/
├── TextGrab/
│   ├── App/
│   │   ├── AppDelegate.swift          # App lifecycle, menu bar setup
│   │   ├── TextGrabApp.swift          # @main entry, DI container
│   │   ├── AppState.swift             # Global state machine + errors
│   │   └── CaptureCoordinator.swift   # Orchestrates capture→OCR→clipboard
│   ├── Capture/
│   │   └── ScreenCaptureManager.swift # ScreenCaptureKit wrapper
│   ├── Selection/
│   │   ├── SelectionController.swift  # Region selection overlay
│   │   └── SelectionOverlayView.swift # SwiftUI overlay view
│   ├── OCR/
│   │   ├── OCRManager.swift           # Vision request execution
│   │   ├── OCRModels.swift            # OCRMode, OCRConfiguration, results
│   │   └── TextProcessor.swift        # Post-processing (ordering, cleanup)
│   ├── Clipboard/
│   │   └── ClipboardManager.swift     # Clipboard + history
│   ├── Shortcut/
│   │   └── GlobalShortcutManager.swift# Carbon hotkey registration
│   ├── MenuBar/
│   │   └── MenuBarView.swift          # Menu bar popover UI
│   ├── Settings/
│   │   ├── SettingsManager.swift      # UserDefaults persistence
│   │   └── SettingsView.swift         # Tabbed settings (General/OCR/Permissions/Advanced)
│   ├── Permissions/
│   │   └── PermissionsManager.swift   # Screen Recording & Accessibility
│   ├── Utilities/
│   │   ├── AppleIntelligenceService.swift # macOS 26+ AI features
│   │   ├── NotificationManager.swift  # User notifications
│   │   ├── TextToSpeechManager.swift  # AVSpeechSynthesizer wrapper
│   │   ├── Logger.swift               # OSLog wrapper
│   │   └── Extensions.swift           # Shared extensions
│   ├── Assets.xcassets/
│   └── Supporting Files/
├── TextGrabTests/                     # Unit tests
├── TextGrabUITests/                   # UI tests
├── LICENSE
├── SECURITY.md
└── README.md
```

## Development Status

Current target: **v1.0 product build**

The complete local workflow is implemented:

```text
⌘⇧2
  ↓
Selection overlay
  ↓
Capture selected region
  ↓
Vision OCR
  ↓
Copy text
```

### Implemented
- Menu bar application with popover
- Global shortcut registration (Carbon)
- Region selection overlay with multi-monitor support
- Single-frame screen capture via ScreenCaptureKit
- Vision OCR with 3 modes (Text/Code/Table)
- Configurable recognition level & languages
- Text ordering/cleanup (reading order)
- Clipboard output + optional bounded history
- Escape to cancel selection
- Screen-capture & Accessibility permission handling
- Notifications
- Text-to-speech
- Apple Intelligence correction/summarize/compact (macOS 26+)
- Settings persistence (UserDefaults)
- Unit tests for text processing

### In Progress / Planned
- Code signing, notarization, distribution (DMG/pkg)
- Sparkle updater integration
- Localization

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15.4+
- Screen Recording permission (mandatory)
- Accessibility permission (optional, improves keyboard integration)

## Building

```bash
xcodebuild -project TextGrab.xcodeproj -scheme TextGrab -configuration Release
```

## License

MIT — see [LICENSE](LICENSE)

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.