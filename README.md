# TextGrab

Native macOS utility for extracting text from anywhere on the screen.

**Tagline:** Instant screen-to-text for macOS.

[![Download](https://img.shields.io/github/v/release/arsh342/TextGrab?style=for-the-badge&label=Download&logo=apple&color=success)](https://github.com/arsh342/TextGrab/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)

[Download the latest DMG →](https://github.com/arsh342/TextGrab/releases/latest)

https://github.com/user-attachments/assets/a2b095a7-f1a2-421f-b2fb-fd32ead2211a

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
  - **Text** — General purpose text extraction with language correction (Fast or Accurate, Fast by default)
  - **Code** — Optimized for code snippets: rebuilds indentation from layout, joins OCR-split punctuation, always uses Accurate recognition
  - **Table** — Extracts tabular data as GitHub-flavored markdown: space-aligned and pipe-delimited columns, wrapped-cell and hyphen rejoining, always uses Accurate recognition
- **Smart recognition policy** — Text mode is user-configurable (Fast/Accurate); Code and Table always run Accurate automatically since Fast misses isolated digits and small cells
- **OCR robustness** — Auto-retry chain for tricky captures: Accurate retry and image inversion for white text on dark backgrounds (dark-mode IDEs, dark theme apps)
- **Pipeline timeouts** — Capture, OCR, and AI steps are race-guarded so a hung system call can never leave the app stuck
- **Multi-language OCR** — Add custom languages (e.g., `fr-FR`, `ja-JP`, `zh-Hans`)

### Clipboard & History
- **Clipboard history** — Optional history with configurable max items (10–200) that **survives app relaunches** (stored locally, bounded, wiped when disabled)
- **One-click recopy** — Click any history item to copy it again
- **Rich-text tables** — Markdown tables are also placed on the clipboard as HTML so pasting into Notes/Pages/Word preserves the table

### Text-to-Speech
- **Speak captured text** — Built-in TTS with play/stop controls in the menu bar

### Apple Intelligence (macOS 26+)
- **On-device correction** — Uses Apple Intelligence to fix OCR errors before copying (runs entirely on-device, no cloud)
- **Summarize** — Generate a concise summary of captured text with one click
- **Compact** — Create a condensed version preserving key information
- **Privacy-first** — All processing happens locally; no data leaves your Mac

### Menu Bar Interface
- Polished popover with material cards, a prominent Capture button, and hover highlights
- Custom extraction mode selector (Text/Code/Table) with live switching
- Real-time processing status and inline error reporting
- Selectable last-capture preview, window nudged away from the screen edge

### Auto-Updates
- **GitHub Releases based** — Checks the latest release once a day on launch (opt-out toggle)
- **Check Now** — Manual check in Settings with live status and semantic version comparison
- **Download & install** — Downloads the DMG and opens it for drag-to-install; no signing infrastructure required
- **Update notifications** — Notifies when a newer version is available

### Localization
- **5 languages** — English (source), Hindi (हिन्दी), French (Français), German (Deutsch), Spanish (Español)
- The UI follows the system language automatically via String Catalogs

### Privacy & Permissions
- **100% local processing** — No data sent to external servers
- **Permission management** — Built-in UI for Screen Recording and Accessibility permissions
- **Relaunch helper** — One-click app restart after granting permissions (spawns a fresh instance)

### Settings
- **General** — Shortcuts, notifications, history
- **OCR** — Mode, recognition level, language correction, Apple Intelligence, languages
- **Permissions** — Grant/check Screen Recording & Accessibility
- **Advanced** — Updates, version info, user guide, links to source/privacy

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
- **Frameworks:** Vision, ScreenCaptureKit, CoreGraphics, CoreImage, Foundation, Carbon (for global shortcuts), UserNotifications, AVFoundation, ServiceManagement, FoundationModels (Apple Intelligence, macOS 26+)
- **Architecture:** MVVM with `@ObservableObject`/`@StateObject`
- **Testing:** XCTest (unit), XCUITest (UI)
- **External dependencies:** None

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
│   │   ├── UpdateManager.swift          # GitHub Releases auto-updater
│   │   ├── NotificationManager.swift    # User notifications
│   │   ├── TextToSpeechManager.swift    # AVSpeechSynthesizer wrapper
│   │   ├── Logger.swift                 # OSLog wrapper
│   │   └── Extensions.swift             # Shared extensions
│   ├── Assets.xcassets/
│   ├── TextGrab.icon/                   # Icon Composer project (light/dark/tinted)
│   └── Supporting Files/                # Info.plist, entitlements, Localizable.xcstrings
├── TextGrabTests/                     # Unit tests
├── TextGrabUITests/                   # UI tests
├── LICENSE
├── SECURITY.md
└── README.md
```

## Development Status

Current target: **v1.1.0 product build**

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
- Menu bar application with polished popover UI
- Global shortcut registration (Carbon)
- Region selection overlay with multi-monitor support
- Single-frame screen capture via ScreenCaptureKit with pipeline timeouts
- Vision OCR with 3 modes (Text/Code/Table) and smart recognition policy
- Code indentation/punctuation reconstruction and GitHub-style table output
- OCR retry chain for white-on-dark captures and missed table cells
- Text ordering/cleanup (reading order)
- Clipboard output + bounded persistent history + HTML table flavor
- Escape to cancel selection
- Screen-capture & Accessibility permission handling with working relaunch
- Notifications
- Text-to-speech
- Apple Intelligence correction/summarize/compact (macOS 26+)
- Settings persistence (UserDefaults)
- Auto-updater via GitHub Releases
- Localization: English, Hindi, French, German, Spanish
- Dark mode app icon (Icon Composer, light/dark/tinted)
- 12 unit tests + 2 UI tests

### In Progress / Planned
- Developer ID code signing & notarization for distribution
- QR/barcode detection

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 26+ (compiles the Icon Composer app icon)
- Screen Recording permission (mandatory)
- Accessibility permission (optional, improves keyboard integration)

## Building

```bash
# Debug build
xcodebuild -project TextGrab.xcodeproj -scheme TextGrab -configuration Debug build

# Release archive + DMG (outputs build/TextGrab-1.1.0.dmg)
./scripts/build-release.sh

# Run tests (12 unit + 2 UI)
xcodebuild -project TextGrab.xcodeproj -scheme TextGrab -configuration Debug test
```

THIS IS NOT THE FINAL BUILD. SO, THERE MIGHT BE SOME BUGS YOU CAN EXPERIENCE.

## License

MIT — see [LICENSE](LICENSE)

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.
